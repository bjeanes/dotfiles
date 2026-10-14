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
      mkTailscaleQuadletContainer = myLib.mkTailscaleQuadletContainer pkgs config;
      mkQuadletDynamicEnvironment = myLib.mkQuadletDynamicEnvironment pkgs config;

      inherit (config.virtualisation.quadlet) pods volumes;

      podName = "${svc}-pod";
      fqdn = "${cfg.hostName}.${config.homelab.tailscale.tailnet}";

      dbName = "${svc}-db";

      port = 3000;
      dbPort = 5432;

      dbUser = svc;
      dbDatabase = svc;
      dbPassword = svc;

      # Covers, uploads (`book-bucket`) and other app state. The entrypoint
      # chowns it to PUID:PGID on every start.
      dataDir = "${cfg.configDir}/data";

      # Nightly `pg_dump`s land here. rsyncing this is a real backup; rsyncing
      # a live PGDATA is not, which is why the database itself lives in a
      # podman volume rather than under `configDir`. The dump runs an hour
      # before `buildBackupScriptForDir`'s 02:00 rsync.
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

            volumes."${svc}-pgdata" = { };

            containers.${dbName} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                image = cfg.dbImage;
                # Only the pod needs to reach this.
                exec = [
                  "postgres"
                  "-c"
                  "listen_addresses=127.0.0.1"
                ];
                environments = {
                  TZ = cfg.timeZone;
                  POSTGRES_USER = dbUser;
                  POSTGRES_DB = dbDatabase;
                  POSTGRES_PASSWORD = dbPassword;
                };
                # pg18 images keep PGDATA in a major-versioned subdirectory,
                # so the volume goes one level up.
                volumes = [
                  "${volumes."${svc}-pgdata".ref}:/var/lib/postgresql"
                ];
                notify = "healthy";
                healthCmd = "pg_isready -U ${dbUser} -d ${dbDatabase}";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 10;
              };
              # First boot runs initdb before the healthcheck can pass.
              serviceConfig.TimeoutStartSec = "300";
            };

            containers.${svc} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                autoUpdate = "registry";
                image = cfg.image;

                environments = {
                  TZ = cfg.timeZone;

                  NODE_ENV = "production";
                  HOST = "127.0.0.1";
                  PORT = toString port;

                  POSTGRES_HOST = "localhost";
                  POSTGRES_PORT = toString dbPort;
                  POSTGRES_USER = dbUser;
                  POSTGRES_PASSWORD = dbPassword;
                  POSTGRES_DB = dbDatabase;

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
                  "${dbName}.service"
                  mountUnit
                ];
                Requires = [ "${dbName}.service" ];
                BindsTo = [ mountUnit ];
                AssertPathIsDirectory = [ dataDir ];
              };
            };
          };

          systemd.services."${svc}-db-dump" = {
            description = "Dump ${svc}'s database";
            startAt = "*-*-* 01:00:00 ${cfg.timeZone}";
            requires = [ "${dbName}.service" ];
            after = [ "${dbName}.service" ];
            serviceConfig.Type = "oneshot";
            script = ''
              set -eu
              ${pkgs.podman}/bin/podman exec ${dbName} \
                pg_dump -U ${dbUser} -d ${dbDatabase} -Fc > ${backupDir}/${svc}.dump.tmp
              mv ${backupDir}/${svc}.dump.tmp ${backupDir}/${svc}.dump
            '';
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

        (mkTailscaleQuadletContainer "${svc}-tailscale" {
          inherit podName;
          hostname = cfg.hostName;
          https = port;
        })

        (lib.mkIf cfg.backupToNAS (buildBackupScriptForDir cfg.configDir { inherit (cfg) timeZone; }))
      ]
    );
}
