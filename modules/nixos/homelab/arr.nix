{ lib, config, ... }:
let
  coalesce = val: default: if (val == null) then default else val;
  mkArr = name: {
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

    config = lib.mkIf config.homelab.services.${name}.enable (
      let
        cfg = config.homelab.services.${name};
      in
      {
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

        virtualisation.oci-containers = {
          containers.${name} = {
            image = cfg.image;
            autoStart = true;
            extraOptions =
              [
                "--pull=newer"
              ]
              ++ lib.optionals cfg.tailscale.enable [
                "--network=container:${name}-tailscale"
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

            dependsOn = lib.optionals cfg.tailscale.enable [ "${name}-tailscale" ];
          };
        };
      }
    );
  };
in
{
  imports = [
    (mkArr "sonarr")
    (mkArr "radarr")
  ];
}
