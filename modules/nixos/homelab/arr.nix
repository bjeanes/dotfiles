{ lib, config, ... }:
let
  mkArr = name: config: serviceConfig:
    {
      options.homelab = {
        "services.${name}" = {
          enable = lib.mkOption {
            default = false;
            type = lib.types.bool;
            description = "Enable ${name}";
          };

          tailscale = {
            enable = lib.mkOption {
              default = config.homelab.tailscale;
              type = lib.types.bool;
              description = "Enable Tailscale for ${name}";
            };
          };

          user = lib.mkOption {
            default = name;
            type = with lib.types; either int str;
            description = ''
              User to run ${name} services as
            '';
          };

          group = lib.mkOption {
            default = config.homelab.group;
            type = with lib.types; either int str;
            description = ''
              Group to run the homelab services as
            '';
          };
        };
      };

      config =
        let
          backend = config.virtualisation.oci-containers.backend;
          cfg = config.homelab.services.${name};
          configDir = "/var/lib/homelab/${name}";
          uid = lib.mkIf (builtins.isInt cfg.user) cfg.user (config.users.users."${cfg.user}".uid);
          gid = lib.mkIf (builtins.isInt cfg.group) cfg.group (config.users.group."${cfg.group}".gid);
        in
        lib.optionalAttrs cfg.enable {
          systemd.tmpfiles.rules = map (x: "d ${x} 0775 ${uid} ${gid} - -") [
            configDir
          ];

          users.users = lib.optionalAttrs (lib.isString cfg.user) {
            ${cfg.user} = {
              isSystemUser = true;
              group = cfg.group;
            };
          };

          # `virtualisation.oci-containers` options don't allow for setting dependencies on non-docker services
          # But we need this to depend on our NFS mounts to the NAS.
          systemd.services = {
            "${backend}-${name}" = {
              requires = [ "nas-media.automount" ];
            };
          };

          virtualisation.oci-containers = {
            containers = {
              ${name} = {
                image = serviceConfig.image or "lscr.io/linuxserver/${name}:latest";
                autoStart = true;
                extraOptions = [
                  "--pull=newer"
                ] + lib.options cfg.tailscale.enable [
                  "--network=container:${name}-tailscale"
                ];
                volumes = [
                  "/nas/media:/data"
                ];
                environment = {
                  TZ = cfg.timeZone;
                  PUID = uid;
                  GUID = gid;
                  UMASK = "002";
                };

                dependsOn = lib.optionals cfg.tailscale.enable [ "${name}-tailscale" ];
              } // lib.optionalAttrs cfg.tailscale.enable {
                "${name}-tailscale" = {
                  enable = true;
                };
              };
            };
          };
        };
    };
in
{
  imports = [
    (mkArr "sonarr" config { })
    (mkArr "radarr" config { })
  ];
}
