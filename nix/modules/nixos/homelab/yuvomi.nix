{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  svc = "yuvomi";
  secretFile = flake.lib.mkSecretFileOption config svc;
in
{
  options.homelab.services.${svc} =
    flake.lib.mkHomelabServiceOptions config svc {
      image = "ghcr.io/ulsklyc/${svc}:latest";
      hostName = svc;
      dashboard.description = "Household documents, health records and finances";
      dashboard.icon = "mdi-home-heart";
      withUser = true;
      backupDescription = "Back up ${svc}'s database dumps to legacy location on NAS";
    }
    // {
      sessionSecretFile = secretFile "session-secret" "File containing the key ${svc} signs session cookies with";

      encryptDatabase = lib.mkOption {
        default = true;
        type = lib.types.bool;
        description = ''
          Encrypt the SQLite database at rest with AES-256 (SQLCipher).

          This is a one-way door. An existing plaintext database is encrypted on
          the next start, and from then on the key is the only way back into it —
          a wrong or missing key aborts the boot rather than degrading to
          plaintext. Turning this off again means restoring from a backup.
        '';
      };

      dbEncryptionKeyFile = secretFile "db-encryption-key" "File containing the key ${svc}'s database is encrypted with";
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
      port = 3000;

      dataDir = "${cfg.configDir}/data";

      # Yuvomi's own scheduled backups (SQLCipher-aware dumps) land here.
      # rsyncing this is a real backup; rsyncing the live database under
      # `dataDir` is not, which is why only this directory goes to the NAS.
      # The dump runs an hour before `buildBackupScriptForDir`'s 02:00 rsync so
      # each night ships that night's dump rather than the previous one's.
      backupDir = "${cfg.configDir}/backups";
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

          systemd.tmpfiles.rules =
            let
              inherit (cfg) user group;
            in
            [
              # Not group-readable: this holds the household's documents,
              # health records and finances, and nothing outside the container
              # reads it.
              "d ${cfg.configDir} 0700 ${user} ${group} - -"
              "d ${dataDir}       0700 ${user} ${group} - -"
              "d ${backupDir}     0700 ${user} ${group} - -"

              "Z ${cfg.configDir} - ${user} ${group} - -"
            ];

          virtualisation.quadlet = {
            pods.${podName} = { };

            containers.${svc} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                autoUpdate = "registry";
                image = cfg.image;

                # Started as root, the image's entrypoint would chown the
                # volumes to the image's own `node` user — uid 1000, which
                # rootful podman maps straight through to uid 1000 on the
                # host, i.e. bjeanes. Started as a non-root user it skips all
                # of that and execs the server directly (upstream's TrueNAS
                # path), so the data stays owned by the uid tmpfiles gave it
                # above. `--hostuser` copies the passwd entry in so podman can
                # resolve the name.
                user = cfg.user;
                podmanArgs = [ "--hostuser=${cfg.user}" ];

                environments = {
                  TZ = cfg.timeZone;

                  NODE_ENV = "production";
                  PORT = toString port;

                  DB_PATH = "/data/${svc}.db";
                  BACKUP_DIR = "/backups";
                  BACKUP_ENABLED = "true";
                  BACKUP_SCHEDULE = "0 1 * * *";
                  BACKUP_KEEP = "7";

                  # Keep uploaded documents as BLOBs in the database rather
                  # than loose files: that is the only arrangement where the
                  # nightly dump above is a complete backup, and where the
                  # at-rest encryption covers them too.
                  DOCUMENT_STORAGE_LOCAL_ENABLED = "false";

                  # tailscaled terminates TLS and proxies plaintext to `port`,
                  # so the app only sees the public scheme and client address
                  # through `X-Forwarded-*`. Without both of these, session
                  # cookies lose their `Secure` attribute and logins fail.
                  SESSION_SECURE = "true";
                  TRUST_PROXY = "1";

                  # The request Host header is never trusted for password-reset
                  # and invitation links, so those mails go unsent without this.
                  BASE_URL = "https://${fqdn}";
                };
                volumes = [
                  "${dataDir}:/data"
                  "${backupDir}:/backups"
                ];

                # Gives `podman auto-update` something to roll back on, and the
                # endpoint is unauthenticated by design.
                healthCmd = "node -e 'require(\"http\").get(\"http://127.0.0.1:${toString port}/health\", r => process.exit(r.statusCode === 200 ? 0 : 1))'";
                healthInterval = "30s";
                healthTimeout = "10s";
                healthRetries = 3;
                healthStartPeriod = "10s";
              };
              unitConfig = {
                AssertPathIsDirectory = [
                  dataDir
                  backupDir
                ];
              };
            };
          };
        }

        (mkQuadletDynamicEnvironment {
          containerName = svc;
          variables = {
            SESSION_SECRET = "cat ${lib.escapeShellArg cfg.sessionSecretFile}";
          }
          // lib.optionalAttrs cfg.encryptDatabase {
            DB_ENCRYPTION_KEY = "cat ${lib.escapeShellArg cfg.dbEncryptionKeyFile}";
          };
        })

        (mkTailscaleQuadletExposure svc { https = port; })

        (lib.mkIf cfg.backupToNAS (buildBackupScriptForDir backupDir { inherit (cfg) timeZone; }))
      ]
    );
}
