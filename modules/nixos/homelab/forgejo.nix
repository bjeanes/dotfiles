{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
let
  svc = "forgejo";
in
{
  options.homelab.services.${svc} = {
    enable = lib.mkEnableOption svc;
    configDir = lib.mkOption {
      default = "/var/lib/homelab/${svc}";
      example = "/var/lib/homelab/${svc}";
      type = lib.types.str;
      description = "Location to store ${svc} config";
    };

    timeZone = lib.mkOption {
      default = config.homelab.timeZone;
      type = lib.types.str;
      description = "Time zone for ${svc}";
    };

    backupToNAS = lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = "Back up configDir to legacy location on NAS";
    };
  };

  config =
    let
      cfg = config.homelab.services.${svc};
      myLib = lib.${namespace};
      svcName = myLib.containerSvcName config svc;
      setEnvFromCommandsForContainer = myLib.setEnvFromCommandsForContainer config;
      mkTailscaleContainer = myLib.mkTailscaleContainer pkgs config;
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          users.users = {
            ${svc} = {
              isSystemUser = true;
              group = "homelab";
            };
          };

          users.groups.homelab = { };

          systemd.tmpfiles.rules = [
            # Ensure config directory exists, owned by user
            "d ${cfg.configDir}/data   0775 ${svc} homelab - -"
            "d ${cfg.configDir}/pgdata 0775 ${svc} homelab - -"

            # Ensure directory and contents belong to specified owner and group
            "Z ${cfg.configDir}/data   - ${svc} homelab - -"
            "Z ${cfg.configDir}/pgdata - ${svc} homelab - -"
          ];

          virtualisation.oci-containers.containers = {
            ${svc} = {
              image = "codeberg.org/forgejo/forgejo:10";
              autoStart = true;
              dependsOn = [
                "${svc}-db"
                "${svc}-tailscale"
              ];
              extraOptions = [
                # "--pull=always"
                "--network=container:${svc}-tailscale"
              ];
              environment = {
                TZ = cfg.timeZone;
                FORGEJO_database_DB_TYPE = "postgres";
                FORGEJO_database_HOST = "localhost"; # "${svc}-db";
                FORGEJO_database_USER = "gitea"; # "${svc}";
                FORGEJO_database_PASSWD = "gitea"; # "${svc}";
                FORGEJO_database_NAME = "gitea"; # "${svc}";
              };
              volumes = [
                "${cfg.configDir}/data:/data"
                "/etc/localtime:/etc/localtime:ro"
              ];
            };

            "${svc}-db" = {
              image = "postgres:17.2";
              user = svc;
              dependsOn = [ "${svc}-tailscale" ];
              extraOptions = [
                # workaround Forgejo on TS network not being able to resolve db
                "--network=container:${svc}-tailscale"
                "--hostuser=${svc}"
                # "--pull=always"
              ];
              environment = {
                POSTGRES_USER = "gitea"; # "${svc}";
                POSTGRES_PASSWORD = "gitea"; # "${svc}";
                POSTGRES_DB = "gitea"; # "${svc}";
              };
              volumes = [
                "${cfg.configDir}/pgdata-17:/var/lib/postgresql/data"
              ];
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
                ${pkgs.rsync}/bin/rsync -avuP --no-o --no-g ${lib.escapeShellArg cfg.configDir}/* /mnt/nfs/tempnas/docker/${svc}/
            '';
          };
        })

        # Nix expressions give us no way to derive the UID from a user at
        # evaluation time, so this delays resolution of user/group names
        # to UID/GID at service start time, by modifying the
        # systemd.service record for the docker container.
        (setEnvFromCommandsForContainer svc {
          USER_UID = "${pkgs.coreutils}/bin/id -u ${svc}";
          GROUP_GID = "${pkgs.getent}/bin/getent group homelab | cut -d: -f3";
        })

        (mkTailscaleContainer "${svc}-tailscale" {
          storePath = "${cfg.configDir}/ts";
          hostname = svc;
          serve = {
            TCP."443".HTTPS = true;
            TCP."22".TCPForward = "localhost:2222";
            Web."\${TS_CERT_DOMAIN}:443".Handlers."/".Proxy = "http://localhost:3000";
          };
        })
      ]
    );
}
