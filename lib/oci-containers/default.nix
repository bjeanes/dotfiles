{
  lib,
  namespace,
  ...
}:
let
  myLib = lib.${namespace};
  inherit (myLib) mkTailscaleServeConfig;
in
rec {
  containerSvcName =
    config: name: config.virtualisation.oci-containers.containers.${name}.serviceName;

  # Allow setting environment variables on an oci-container declaration from the contents of a file
  setEnvFromFilesForContainer =
    pkgs: config: name: vars:
    setEnvFromCommandsForContainer pkgs config name (
      builtins.mapAttrs (_: v: "cat ${lib.escapeShellArg v}") vars
    );

  # Allow setting environment variables on an oci-container declaration from the output of a command
  setEnvFromCommandsForContainer =
    pkgs: config: containerName: variables:
    mkOciDynamicEnvironment pkgs config { inherit variables containerName; };

  mkOciDynamicEnvironment =
    pkgs: config:
    {
      containerName,
      variables,
    }:
    let
      serviceName = containerSvcName config containerName;

      generated = mkDynamicEnvFile pkgs {
        inherit serviceName variables;
      };
    in
    {
      virtualisation.oci-containers.containers.${containerName}.environmentFiles = [
        generated.envFile
      ];

      systemd.services.${serviceName}.serviceConfig = {
        ExecStartPre = lib.mkAfter [ generated.execStartPre ];
        ExecStopPost = lib.mkAfter [ generated.execStopPost ];
      };
    };

  mkQuadletDynamicEnvironment =
    pkgs: config:
    {
      containerName,
      variables,
    }:
    let
      serviceName = "${containerName}.service";

      generated = mkDynamicEnvFile pkgs {
        inherit serviceName variables;
      };
    in
    {
      virtualisation.quadlet.containers.${containerName} = {
        containerConfig.environmentFiles = [
          generated.envFile
        ];

        serviceConfig = {
          RuntimeDirectory = lib.mkDefault containerName;
          ExecStartPre = lib.mkAfter [ generated.execStartPre ];
          ExecStopPost = lib.mkAfter [ generated.execStopPost ];
        };
      };
    };

  mkDynamicEnvFile =
    pkgs:
    {
      serviceName,
      variables,
      fragmentName ? lib.concatStringsSep "-" (builtins.attrNames variables),
    }:
    let
      publicDirectory = "/run/dynamic-container-env/${serviceName}";

      # Inside the script which generates the env, $RUNTIME_DIRECTORY will be
      # set by systemd, but in order to configure podman to use the env file,
      # a statically known name must be used. We use a symlink to the runtime
      # location so that systemd can clean up the real file. This will leave
      # a dangling symlink but it will at least not leave behind the file
      # contents (which might contain secrets).
      envFileSymlink = "${publicDirectory}/${fragmentName}.env";

      clean = (
        pkgs.writeShellScript "cleanup-${serviceName}-env" ''
          set -euo pipefail

          rm -f ${lib.escapeShellArg envFileSymlink}
          rmdir --ignore-fail-on-non-empty ${lib.escapeShellArg publicDirectory}
        ''
      );

      generate = pkgs.writeShellScript "generate-${serviceName}-${fragmentName}-env" /* bash */ ''
        set -euo pipefail

        realEnvFile="$RUNTIME_DIRECTORY/${fragmentName}.env"

        ${pkgs.coreutils}/bin/install \
          -d \
          -m 0700 \
          ${lib.escapeShellArg publicDirectory}

        tmp="$(${pkgs.coreutils}/bin/mktemp $RUNTIME_DIRECTORY/.${lib.escapeShellArg fragmentName}.XXXXX)"

        cleanup() {
          rm -f "$tmp"
        }
        trap cleanup EXIT

        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (variable: command: /* bash */ ''
            value="$(
              ${command}
            )"

            # Podman env files are line-oriented. Reject values that
            # cannot be represented unambiguously.
            case "$value" in
              *$'\n'*)
                echo Dynamic environment variable ${lib.escapeShellArg variable} contains a newline >&2
                exit 1
                ;;
            esac

            printf '%s=%s\n' \
              ${lib.escapeShellArg variable} \
              "$value" \
              >> "$tmp"
          '') variables
        )}

        ${pkgs.coreutils}/bin/chmod 0600 "$tmp"
        ${pkgs.coreutils}/bin/mv -f "$tmp" "$realEnvFile"
        trap - EXIT

        ${pkgs.coreutils}/bin/ln -sfn "$realEnvFile" ${lib.escapeShellArg envFileSymlink}
      '';
    in
    {
      envFile = envFileSymlink;
      execStartPre = generate;
      execStopPost = clean;
    };

  mkTailscaleContainer =
    pkgs: config: name:
    {
      container ? { },
      ...
    }@opts:
    with lib;
    let
      rest = removeAttrs opts [ "container" ];
      common = mkTailscaleContainerCommon pkgs config name rest;
    in
    mkMerge [
      common.config
      {
        virtualisation.oci-containers.containers.${name} = container;
      }
      (mkOciDynamicEnvironment pkgs config {
        containerName = name;
        variables = common.dynamicEnvironment;
      })
      {
        virtualisation.oci-containers.containers.${name} = {
          inherit (common)
            environment
            volumes
            image
            hostname
            ;
          extraOptions = [
            "--cap-add=net_admin"
            "--cap-add=sys_module"
          ];
          labels = {
            "io.containers.autoupdate" = "registry";
          };
        };
      }
    ];

  mkTailscaleContainerCommon =
    pkgs: config: name:
    {
      hostname ? name,
      authKeyFile ? config.age.secrets.tailscale-auth-service.path,
      storePath ? "/var/lib/tailscale/ctr-${name}", # NOTE: ignored if ephemeral
      image ? "docker.io/tailscale/tailscale:latest",
      ephemeral ? false,
      https ? null,
      tcp ? null,
      funnel ? null,
      tags ? [
        "tag:home"
        "tag:service"
      ],
    }@opts:
    with lib;
    let
      serveJson = mkTailscaleServeConfig pkgs {
        inherit https tcp funnel;
      };
      hasServeConfig = serveJson != null;
    in
    {
      inherit image hostname;
      environment = {
        TS_EXTRA_ARGS = "--advertise-tags=${concatStringsSep "," tags}";
        TS_HOSTNAME = hostname;
        TS_ACCEPT_DNS = "true";
        TS_AUTH_ONCE = "true";
      }
      // optionalAttrs ephemeral {
        TS_TAILSCALED_EXTRA_ARGS = "--state=mem:";
      }
      // optionalAttrs (!ephemeral) {
        TS_STATE_DIR = "/var/lib/tailscale";
      }
      // optionalAttrs hasServeConfig {
        TS_SERVE_CONFIG = "/config/serve.json";
      };

      dynamicEnvironment = {
        TS_AUTHKEY = "cat ${escapeShellArg authKeyFile} | tr -d '\n' && echo -n '?ephemeral=${
          if ephemeral then "true" else "false"
        }'";
      };

      volumes =
        (optionals (!ephemeral) [ "${storePath}:/var/lib/tailscale" ])
        ++ (optionals hasServeConfig [ "${builtins.dirOf serveJson}:/config:ro" ]);

      config.systemd.tmpfiles.rules = optionals (!ephemeral) [ "d ${storePath} 0775 root root - -" ];
    };

  mkTailscaleQuadletContainer =
    pkgs: config: name:
    {
      podName ? "${name}-pod",
      pod ? config.virtualisation.quadlet.pods.${podName}.ref,
      ...
    }@opts:
    with lib;
    let
      rest = removeAttrs opts [
        "pod"
        "podName"
      ];
      common = mkTailscaleContainerCommon pkgs config name rest;
    in
    mkMerge [
      common.config

      (mkQuadletDynamicEnvironment pkgs config {
        containerName = name;
        variables = common.dynamicEnvironment;
      })

      {
        virtualisation.quadlet.containers.${name} = {
          autoStart = true;
          containerConfig = {
            inherit (common) image volumes;
            inherit pod;
            autoUpdate = "registry";
            environments = common.environment;
            addCapabilities = [
              "NET_ADMIN"
              "SYS_MODULE"
            ];
          };
        };
      }
    ];

}
