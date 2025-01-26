{ lib, namespace, ... }:
rec {
  containerSvcName = config: name: "${config.virtualisation.oci-containers.backend}-${name}";

  # Allow setting environment variables on an oci-container declaration from the contents of a file
  setEnvFromFilesForContainer =
    config: name: vars:
    setEnvFromCommandsForContainer config name (
      builtins.mapAttrs (_: v: "cat ${lib.escapeShellArg v}") vars
    );

  # Allow setting environment variables on an oci-container declaration from the output of a command
  setEnvFromCommandsForContainer =
    config: name: vars: with lib; {
      # Add `-e VAR` to add var to container from context environment
      virtualisation.oci-containers.containers.${name}.extraOptions = map (n: "-e=${escapeShellArg n}") (
        builtins.attrNames vars
      );

      systemd.services."${containerSvcName config name}".script = mkBefore (
        concatStringsSep "\n" (mapAttrsToList (k: cmd: ''export ${escapeShellArg k}="$(${cmd})"'') vars)
      );
    };

  mkTailscaleContainer =
    pkgs: config: name:
    {
      hostname ? name,
      authKeyFile ? config.age.secrets.tailscale-auth-service.path,
      ephemeral ? false,
      storePath ? "/var/lib/tailscale/ctr-${name}", # NOTE: ignored if ephemeral
      tags ? [
        "tag:home"
        "tag:service"
      ],
      serve ? { },
      container ? { },
    }:
    with lib;
    mkMerge [
      {
        virtualisation.oci-containers.containers.${name} = {
          inherit hostname;
          image = "tailscale/tailscale:latest";
          extraOptions = [
            "--cap-add=net_admin"
            "--cap-add=sys_module"
          ];
          environment = {
            TS_EXTRA_ARGS = "--advertise-tags=${concatStringsSep "," tags}";
            TS_HOSTNAME = hostname;
            TS_ACCEPT_DNS = "true";
          };
        };
      }
      {
        virtualisation.oci-containers.containers.${name} = container;
      }
      (mkIf ephemeral {
        virtualisation.oci-containers.containers.${name}.environment = {
          TS_TAILSCALED_EXTRA_ARGS = "--state=mem:";
        };
      })
      (mkIf (!ephemeral) {
        systemd.tmpfiles.rules = [
          "d ${storePath} 0775 root root - -"
        ];

        virtualisation.oci-containers.containers.${name} = {
          environment = {
            TS_STATE_DIR = "/var/lib/tailscale";
          };
          volumes = [
            "${storePath}:/var/lib/tailscale"
          ];
        };
      })
      (setEnvFromCommandsForContainer config name {
        TS_AUTHKEY = "cat ${escapeShellArg authKeyFile} | tr -d '\n' && echo -n '?ephemeral=${
          if ephemeral then "true" else "false"
        }'";
      })

      # TODO handle building the serve JSON from clearer args so callers don't have to care about Tailscale serve JSON
      # e.g. complicated ts-serve.json:
      # {
      #   "TCP": {
      #     "123": {
      #       "TCPForward": "127.0.0.1:456"
      #     },
      #     "8080": {
      #       "HTTP": true
      #     },
      #     "8443": {
      #       "HTTPS": true
      #     }
      #   },
      #   "Web": {
      #     "${TS_CERT_DOMAIN}:8080": {
      #       "Handlers": {
      #         "/": {
      #           "Proxy": "http://127.0.0.1:8888"
      #         }
      #       }
      #     },
      #     "${TS_CERT_DOMAIN}:8443": {
      #       "Handlers": {
      #         "/": {
      #           "Proxy": "http://127.0.0.1:9999"
      #         },
      #         "/test": {
      #           "Proxy": "https://localhost:9999/hello"
      #         }
      #       }
      #     }
      #   },
      #   "AllowFunnel": {
      #     "bandersnatch.griffin-climb.ts.net:123": true
      #   }
      # }
      {
        systemd.services.${containerSvcName config name}.aliases = [ "${name}.service" ];

        virtualisation.oci-containers.containers.${name} =
          let
            serveJSON = pkgs.writers.writeJSON "ts-serve.json" serve;
          in
          {
            volumes = [ "${serveJSON}:${serveJSON}" ];
            environment = {
              TS_SERVE_CONFIG = toString serveJSON;
            };
          };
      }

    ];
}
