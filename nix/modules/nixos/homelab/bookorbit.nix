{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  svc = "bookorbit";
  secretFile = flake.lib.mkSecretFileOption config svc;
in
{
  options.homelab.services.${svc} =
    flake.lib.mkHomelabServiceOptions config svc {
      image = "ghcr.io/${svc}/${svc}:latest";
      hostName = svc;
      withUser = true;
      backupDescription = "Back up ${svc}'s data and database dumps to legacy location on NAS";
    }
    // {
      dbImage = lib.mkOption {
        # Pinned to a major version and opted out of auto-update
        default = "docker.io/pgvector/pgvector:pg18";
        type = lib.types.str;
        description = "OCI image for the PostgreSQL (with pgvector) backing ${svc}";
      };

      jwtSecretFile = secretFile "jwt-secret" "File containing the key ${svc} signs auth tokens with";

      podcastEncryptionKeyFile = secretFile "podcast-encryption-key" "File containing the key ${svc} encrypts podcast feed URLs with";

      setupBootstrapTokenFile = secretFile "setup-bootstrap-token" "File containing the token the first-run setup wizard asks for";

      bookRequestEncryptionKeyFile = secretFile "book-request-encryption-key" "File containing the key ${svc} encrypts download client and indexer credentials with";
    };

  config =
    let
      myLib = flake.lib;
      cfg = config.homelab.services.${svc};
      buildBackupScriptForDir = myLib.buildBackupScriptForDir pkgs svc;
      mkTailscaleQuadletExposure = myLib.mkTailscaleQuadletExposure pkgs config;
      mkQuadletDynamicEnvironment = myLib.mkQuadletDynamicEnvironment pkgs config;

      inherit (config.virtualisation.quadlet) pods;

      podName = "${svc}-pod";
      fqdn = "${cfg.hostName}.${config.homelab.tailscale.tailnet}";

      pg = myLib.postgresFor svc;

      port = 3000;

      # Covers, uploads (`book-bucket`) and other app state. The entrypoint
      # chowns it to PUID:PGID on every start.
      dataDir = "${cfg.configDir}/data";

      # `pg_dump`s land here, just ahead of each NAS backup. rsyncing this is
      # a real backup; rsyncing a live PGDATA is not, which is why the
      # database itself lives in a podman volume rather than under
      # `configDir`.
      backupDir = "${cfg.configDir}/backups";

      mountUnit = "mnt-nfs-nas-media.mount";
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

          systemd.tmpfiles.rules = [
            "d ${cfg.configDir} 0700 root root - -"
            "d ${dataDir}       0700 ${cfg.user} ${cfg.group} - -"
            "d ${backupDir}     0700 root root - -"
          ];

          virtualisation.quadlet = {
            pods.${podName} = { };

            containers.${svc} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                autoUpdate = "registry";
                image = cfg.image;

                environments = {
                  TZ = cfg.timeZone;

                  NODE_ENV = "production";
                  HOST = myLib.listenAddressFor cfg;
                  PORT = toString port;

                  POSTGRES_HOST = "localhost";
                  POSTGRES_PORT = toString pg.port;
                  POSTGRES_USER = pg.user;
                  POSTGRES_PASSWORD = pg.password;
                  POSTGRES_DB = pg.database;

                  # Used for Kobo sync endpoints and links in emails
                  APP_URL = "https://${fqdn}";

                  LIBRARY_BROWSE_ROOT = "/media";
                };
                volumes = [
                  "${dataDir}:/data"
                  "/mnt/nfs/nas/media:/media"
                ];

                # Upstream's compose hardening
                readOnly = true;
                tmpfses = [ "/tmp" ];
                dropCapabilities = [ "ALL" ];
                addCapabilities = [
                  "CHOWN"
                  "DAC_OVERRIDE"
                  "FOWNER"
                  "SETGID"
                  "SETUID"
                ];
                noNewPrivileges = true;
                stopTimeout = 30;

                # Gives `podman auto-update` something to roll back on.
                healthCmd = "wget -q -T 4 -O /dev/null http://127.0.0.1:${toString port}/api/v1/health";
                healthInterval = "30s";
                healthTimeout = "5s";
                healthRetries = 3;
                healthStartPeriod = "20s";
              };
              unitConfig = {
                After = [
                  pg.unit
                  mountUnit
                ];
                Requires = [ pg.unit ];
                BindsTo = [ mountUnit ];
                AssertPathIsDirectory = [ dataDir ];
              };
            };
          };
        }

        # Nix expressions give us no way to derive the UID from a user at
        # evaluation time, so these resolve at service start.
        (mkQuadletDynamicEnvironment {
          containerName = svc;
          variables = {
            PUID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
            PGID = "${pkgs.getent}/bin/getent group ${cfg.group} | cut -d: -f3";
            JWT_SECRET = "cat ${lib.escapeShellArg cfg.jwtSecretFile}";
            PODCAST_ENCRYPTION_KEY = "cat ${lib.escapeShellArg cfg.podcastEncryptionKeyFile}";
            SETUP_BOOTSTRAP_TOKEN = "cat ${lib.escapeShellArg cfg.setupBootstrapTokenFile}";
            BOOK_REQUEST_ENCRYPTION_KEY = "cat ${lib.escapeShellArg cfg.bookRequestEncryptionKeyFile}";
          };
        })

        (myLib.mkQuadletPostgres config pg {
          inherit podName;
          inherit (cfg) timeZone;
          image = cfg.dbImage;
          containerConfig.healthRetries = 10;
        })

        (mkTailscaleQuadletExposure svc { https = port; })

        (lib.mkIf cfg.backupToNAS (
          lib.mkMerge [
            (myLib.mkPostgresDump pkgs config svc pg backupDir)
            (buildBackupScriptForDir cfg.configDir { inherit (cfg) timeZone; })
          ]
        ))
      ]
    );
}
