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
      hostName = svc;
      dashboard.description = "Code and Git repositories";
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
      mkQuadletDynamicEnvironment = myLib.mkQuadletDynamicEnvironment pkgs config;
      mkTailscaleQuadletExposure = myLib.mkTailscaleQuadletExposure pkgs config;

      inherit (config.virtualisation.quadlet) pods;

      podName = "${svc}-pod";
      dbName = "${svc}-db";

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

          virtualisation.quadlet = {
            pods.${podName} = { };

            containers = {
              ${svc} = {
                autoStart = true;
                containerConfig = {
                  pod = pods.${podName}.ref;
                  image = cfg.image;
                  environments = {
                    TZ = cfg.timeZone;
                    FORGEJO_database_DB_TYPE = "postgres";
                    FORGEJO_database_HOST = "localhost";
                    FORGEJO_database_USER = "gitea";
                    FORGEJO_database_PASSWD = "gitea";
                    FORGEJO_database_NAME = "gitea";
                  };
                  volumes = [
                    "${cfg.configDir}/data:/data"
                    "/etc/localtime:/etc/localtime:ro"
                  ];
                };
                unitConfig = {
                  After = [ "${dbName}.service" ];
                  Requires = [ "${dbName}.service" ];
                };
              };

              ${dbName} = {
                autoStart = true;
                containerConfig = {
                  pod = pods.${podName}.ref;
                  image = cfg.dbImage;
                  user = cfg.user;
                  podmanArgs = [ "--hostuser=${cfg.user}" ];
                  # Only the pod needs to reach this.
                  exec = [
                    "postgres"
                    "-c"
                    "listen_addresses=127.0.0.1"
                  ];
                  environments = {
                    POSTGRES_USER = "gitea";
                    POSTGRES_PASSWORD = "gitea";
                    POSTGRES_DB = "gitea";
                  };
                  volumes = [
                    "${pgData}:/var/lib/postgresql/data"
                  ];
                  # Ready only once it accepts connections, so forgejo can
                  # order itself behind it.
                  notify = "healthy";
                  healthCmd = "pg_isready -U gitea";
                  healthInterval = "10s";
                  healthTimeout = "5s";
                  healthRetries = 5;
                };
                unitConfig.AssertPathIsDirectory = [ pgData ];
              };
            };
          };
        }

        (lib.mkIf cfg.backupToNAS (
          myLib.buildBackupScriptForDir pkgs svc cfg.configDir { inherit (cfg) timeZone; }
        ))

        # Nix expressions give us no way to derive the UID from a user at
        # evaluation time, so these resolve at service start.
        (mkQuadletDynamicEnvironment {
          containerName = svc;
          variables = {
            USER_UID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
            GROUP_GID = "${pkgs.getent}/bin/getent group ${cfg.group} | cut -d: -f3";
          };
        })

        (mkTailscaleQuadletExposure svc {
          https = 3000;
          # Forgejo's built-in SSH server (`START_SSH_SERVER`), which checks
          # keys against its database. The image's OpenSSH on 22 reads an
          # authorized_keys file Forgejo doesn't maintain in that mode.
          tcp."22" = 2222;
        })
      ]
    );
}
