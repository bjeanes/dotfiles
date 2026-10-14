{
  config,
  lib,
  flake,
  pkgs,
  ...
}:
let
  svc = "forgejo";
in
{
  options.homelab.services.${svc} =
    flake.lib.mkHomelabServiceOptions config svc {
      image = "codeberg.org/forgejo/forgejo:16";
      withUser = true;
    }
    // {
      dbImage = lib.mkOption {
        default = "postgres:17.2";
        type = lib.types.str;
        description = "OCI image for the PostgreSQL backing ${svc}";
      };
    };

  config =
    let
      cfg = config.homelab.services.${svc};
      myLib = flake.lib;
      setEnvFromCommandsForContainer = myLib.setEnvFromCommandsForContainer pkgs config;
      mkTailscaleContainer = myLib.mkTailscaleContainer pkgs config;

      # Versioned because major Postgres upgrades need a fresh PGDATA.
      # Postgres refuses to start if it is group- or world-writable.
      pgData = "${cfg.configDir}/pgdata-17";
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          users.users = {
            ${cfg.user} = {
              isSystemUser = true;
              group = cfg.group;
            };
          };

          users.groups.${cfg.group} = { };

          systemd.tmpfiles.rules = [
            # Ensure config directory exists, owned by user
            "d ${cfg.configDir}/data   0775 ${cfg.user} ${cfg.group} - -"
            "d ${pgData} 0700 ${cfg.user} ${cfg.group} - -"

            # Ensure directory and contents belong to specified owner and group
            "Z ${cfg.configDir}/data   - ${cfg.user} ${cfg.group} - -"
            "Z ${pgData} - ${cfg.user} ${cfg.group} - -"
          ];

          virtualisation.oci-containers.containers = {
            ${svc} = {
              image = cfg.image;
              autoStart = true;
              dependsOn = [
                "${svc}-db"
                "${svc}-tailscale"
              ];
              extraOptions = [
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
              image = cfg.dbImage;
              user = cfg.user;
              dependsOn = [ "${svc}-tailscale" ];
              extraOptions = [
                # workaround Forgejo on TS network not being able to resolve db
                "--network=container:${svc}-tailscale"
                "--hostuser=${cfg.user}"
                # "--pull=always"
              ];
              environment = {
                POSTGRES_USER = "gitea"; # "${svc}";
                POSTGRES_PASSWORD = "gitea"; # "${svc}";
                POSTGRES_DB = "gitea"; # "${svc}";
              };
              volumes = [
                "${pgData}:/var/lib/postgresql/data"
              ];
            };
          };
        }

        (lib.mkIf cfg.backupToNAS (
          myLib.buildBackupScriptForDir pkgs svc cfg.configDir { inherit (cfg) timeZone; }
        ))

        # Nix expressions give us no way to derive the UID from a user at
        # evaluation time, so this delays resolution of user/group names
        # to UID/GID at service start time, by modifying the
        # systemd.service record for the docker container.
        (setEnvFromCommandsForContainer svc {
          USER_UID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
          GROUP_GID = "${pkgs.getent}/bin/getent group ${cfg.group} | cut -d: -f3";
        })

        (mkTailscaleContainer "${svc}-tailscale" {
          storePath = "${cfg.configDir}/ts";
          hostname = svc;
          https = 3000;
          tcp = [ 22 ];
        })
      ]
    );
}
