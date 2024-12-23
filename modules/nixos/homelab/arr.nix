{
  lib,
  config,
  pkgs,
  ...
}:
let
  coalesce = val: default: if (val == null) then default else val;
  tsnet = "griffin-climb.ts.net"; # TODO find this a new home
  mkArr = name: svcCfg: {
    options.homelab.services.${name} = {
      enable = lib.mkOption {
        default = false;
        type = lib.types.bool;
        description = "Enable ${name}";
      };

      tailscale = {
        enable = lib.mkOption {
          default = config.homelab.tailscale.enable;
          type = lib.types.bool;
          description = "Enable Tailscale for ${name}";
        };
      };

      user = lib.mkOption {
        default = coalesce config.homelab.user name;
        type = lib.types.str;
        description = ''
          User to run ${name} services as
        '';
      };

      group = lib.mkOption {
        default = config.homelab.group;
        type = lib.types.str;
        description = ''
          Group to run the homelab services as
        '';
      };

      image = lib.mkOption {
        default = "lscr.io/linuxserver/${name}:latest";
        type = lib.types.str;
        description = "Docker image for ${name}";
      };

      configDir = lib.mkOption {
        default = "/var/lib/homelab/${name}";
        example = "/var/lib/homelab/${name}";
        type = lib.types.str;
        description = "Location to store service config";
      };

      timeZone = lib.mkOption {
        default = config.homelab.timeZone;
        type = lib.types.str;
        description = "Time zone for ${name}";
      };
    };

    config =
      let
        cfg = config.homelab.services.${name};
      in
      (lib.mkIf cfg.enable {
        # https://www.man7.org/linux/man-pages/man5/tmpfiles.d.5.html#SYNOPSIS
        systemd.tmpfiles.rules =
          lib.concatMap
            (dir: [
              # Ensure config directory exists, owned by user
              "d ${dir} 0775 ${cfg.user} ${cfg.group} - -"

              # Ensure directory and contents belong to specified owner and group
              "Z ${dir} - ${cfg.user} ${cfg.group} - -"
            ])
            [
              cfg.configDir
            ];

        users.users = {
          "${cfg.user}" = {
            isSystemUser = true;
            group = config.homelab.services.${name}.group;
          };
        };
        users.groups.${cfg.group} = { };

        systemd.services = {
          "${name}" = {
            requires = [ "nas-media.automount" ];
          };
        };

        virtualisation.oci-containers =
          let
            tsName = "${name}-tailscale";
          in
          {
            containers =
              {
                ${name} = {
                  image = cfg.image;
                  autoStart = true;
                  extraOptions = lib.optionals cfg.tailscale.enable [
                    "--network=container:${tsName}"
                  ];
                  volumes = [
                    "/nas/media:/data"
                  ];
                  environment = {
                    TZ = cfg.timeZone;
                    PUID = cfg.user;
                    GUID = cfg.group;
                    UMASK = "002";
                  };

                  dependsOn = lib.optionals cfg.tailscale.enable [ tsName ];
                };
              }
              // lib.optionalAttrs cfg.tailscale.enable {
                ${tsName} =
                  let
                    secretPath = config.age.secrets.tailscale-auth-service.path;
                    entrypoint =
                      # Tailscale docker image only accepts the auth key as an environment variable,
                      # but we have it exposed as a file via agenix; this custom entrypoint will read
                      # that file (mounted in) and export the contents as an environmetn variable.
                      pkgs.writeScript "custom-publish-authkey-entrypoint.sh" # bash
                        ''
                          #!/bin/sh
                          export TS_AUTHKEY="$(cat ${secretPath})";
                          exec /usr/local/bin/containerboot
                        '';
                    serve = pkgs.writers.writeJSON "ts-serve.json" {
                      TCP."443".HTTPS = true;
                      Web."${name}.${tsnet}:443".Handlers."/".Proxy = "http://127.0.0.1:${builtins.toString svcCfg.port}";
                    };
                  in
                  {
                    image = "tailscale/tailscale:latest";
                    volumes = [
                      "${entrypoint}:/entrypoint.sh"
                      "${secretPath}:${secretPath}"
                      "${serve}:${serve}"
                    ];
                    entrypoint = "/entrypoint.sh";
                    extraOptions = [
                      "--cap-add=net_admin"
                      "--cap-add=sys_module"
                    ];
                    environment = {
                      TS_SERVE_CONFIG = "${serve}";
                      TS_EXTRA_ARGS = "--advertise-tags=tag:home,tag:service";
                      TS_HOSTNAME = name;
                    };
                  };
              };
          };
      });
  };
in
{
  imports = [
    (mkArr "sonarr" { port = 8989; })
    (mkArr "radarr" { port = 7878; })
  ];
}
