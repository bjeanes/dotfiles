{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
let
  svc = "silverbullet";
  coalesce = val: default: if (val == null) then default else val;
in
{
  options.homelab.services.${svc} = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable ${svc}";
    };

    image = lib.mkOption {
      default = "zefhemel/silverbullet:latest";
      type = lib.types.str;
      description = "OCI image for ${svc}";
    };

    configDir = lib.mkOption {
      default = "/var/lib/homelab/${svc}";
      example = "/var/lib/homelab/${svc}";
      type = lib.types.str;
      description = "Location to store service config";
    };

    timeZone = lib.mkOption {
      default = config.homelab.timeZone;
      type = lib.types.str;
      description = "Time zone for ${svc}";
    };

    user = lib.mkOption {
      default = coalesce config.homelab.user svc;
      type = lib.types.str;
      description = ''
        User to run ${svc} service as
      '';
    };

    group = lib.mkOption {
      default = config.homelab.group;
      type = lib.types.str;
      description = ''
        Group to run the ${svc} service as
      '';
    };

    backupToNAS = lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = "Back up configDir to legacy location on NAS";
    };
  };

  config =
    let
      myLib = lib.${namespace};
      cfg = config.homelab.services.${svc};
      svcName = myLib.containerSvcName config svc;
      setEnvFromCommandsForContainer = myLib.setEnvFromCommandsForContainer config;
      setEnvFromFilesForContainer = myLib.setEnvFromFilesForContainer config;
      secrets = config.age.secrets;
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          users.users = {
            "${cfg.user}" = {
              isSystemUser = true;
              group = cfg.group;
            };
          };
          users.groups.${cfg.group} = { };

          systemd.services.${myLib.containerSvcName config "${svc}-tailscale"} = {
            partOf = [ "${svc}.service" ];
          };

          systemd.tmpfiles.rules =
            let
              inherit (cfg) user group;
            in
            [
              # Ensure config directory exists, owned by user
              "d ${cfg.configDir}    0775 ${user} ${group} - -"

              # Ensure directory and contents belong to specified owner and group
              "Z ${cfg.configDir} - ${user} ${group} - -"
            ];

          virtualisation.oci-containers = {
            containers = {
              ${svc} = {
                image = cfg.image;
                autoStart = true;
                dependsOn = [ "${svc}-tailscale" ];
                volumes = [
                  "${cfg.configDir}:/space"
                ];
                extraOptions = [
                  "--pull=always"
                  "--network=container:${svc}-tailscale"
                  "--hostuser=${cfg.user}"
                ];
                environment = {
                  TZ = cfg.timeZone;
                  SB_PORT = "3000";
                };
              };
            };
          };
        }

        (lib.mkIf cfg.backupToNAS {
          systemd.services."backup-${svc}-to-NAS" = {
            requires = [ "mnt-nfs-tempnas-docker.mount" ];
            after = [ "mnt-nfs-tempnas-docker.mount" ];
            startAt = "*-*-* 02:00:00 ${cfg.timeZone}";
            serviceConfig = {
              Type = "oneshot";
            };
            script = ''
              set -eu
              ${pkgs.util-linux}/bin/flock /tmp/backup-to-NAS.lock \
                ${pkgs.rsync}/bin/rsync -avuP --no-o --no-g ${lib.escapeShellArg cfg.configDir}/* /mnt/nfs/tempnas/backups/${svc}/
            '';
          };
        })

        (myLib.mkTailscaleContainer pkgs config "${svc}-tailscale" {
          hostname = svc;
          serve = {
            TCP."443".HTTPS = true;
            Web."\${TS_CERT_DOMAIN}:443".Handlers."/".Proxy = "http://localhost:3000";
          };
        })

      ]
    );
}
