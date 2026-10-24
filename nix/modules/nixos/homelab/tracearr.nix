{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  svc = "tracearr";
  secretFile = flake.lib.mkSecretFileOption config svc;
in
{
  options.homelab.services.${svc} =
    flake.lib.mkHomelabServiceOptions config svc {
      image = "ghcr.io/connorgallopo/${svc}:latest";
      hostName = svc;
      dashboard.description = "Who's watching Plex, and from where";
      # A Tautulli alternative
      dashboard.group = "Monitoring";
      dashboard.widget = {
        type = "tracearr";
        secrets.key = "tracearr-api-key";
        # Tautulli lists the streams themselves
        settings.view = "summary";
      };
      backupDescription = "Back up ${svc}'s database dumps to legacy location on NAS";
    }
    // {
      dbImage = lib.mkOption {
        # Pinned to specific version and opted out of auto-update
        default = "docker.io/timescale/timescaledb-ha:pg18.4-ts2.29.1";
        type = lib.types.str;
        description = "OCI image for the TimescaleDB backing ${svc}";
      };

      redisImage = lib.mkOption {
        default = "docker.io/library/redis:8-alpine";
        type = lib.types.str;
        description = "OCI image for the Redis backing ${svc}";
      };

      jwtSecretFile = secretFile "jwt-secret" "File containing the key ${svc} signs auth tokens with";

      cookieSecretFile = secretFile "cookie-secret" "File containing the key ${svc} signs cookies with";
    };

  config =
    let
      myLib = flake.lib;
      cfg = config.homelab.services.${svc};
      buildBackupScriptForDir = myLib.buildBackupScriptForDir pkgs svc;
      mkTailscaleQuadletExposure = myLib.mkTailscaleQuadletExposure pkgs config;
      mkQuadletDynamicEnvironment = myLib.mkQuadletDynamicEnvironment pkgs config;

      inherit (config.virtualisation.quadlet) pods volumes;

      podName = "${svc}-pod";
      fqdn = "${cfg.hostName}.${config.homelab.tailscale.tailnet}";

      pg = myLib.postgresFor svc;
      redisName = "${svc}-redis";

      port = 3000;
      redisPort = 6379;

      # Tracearr's own scheduled backups (pg_dump custom-format archives, zipped)
      # land here. rsyncing this is a real backup; rsyncing a live PGDATA is not,
      # which is why the database itself lives in a podman volume rather than
      # under `configDir`. Schedule and retention are set in Settings -> Backup.
      backupDir = "${cfg.configDir}/backups";
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          # Ownership is left to podman (see the `:U` mount below), so `-`
          # rather than a user: `d` would otherwise reassert root on every
          # activation and undo it.
          systemd.tmpfiles.rules = [
            "d ${cfg.configDir} 0700 - - - -"
            "d ${backupDir} 0700 - - - -"
          ];

          virtualisation.quadlet = {
            pods.${podName} = { };

            volumes."${svc}-redisdata" = { };

            containers.${redisName} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                image = cfg.redisImage;
                exec = [
                  "redis-server"
                  "--appendonly"
                  "yes"
                  # Only the pod needs to reach this.
                  "--bind"
                  "127.0.0.1"
                ];
                environments = {
                  TZ = cfg.timeZone;
                };
                volumes = [
                  "${volumes."${svc}-redisdata".ref}:/data"
                ];
                notify = "healthy";
                healthCmd = "redis-cli ping";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 5;
              };
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
                  HOST = myLib.listenAddressFor cfg;
                  PORT = toString port;
                  LOG_LEVEL = "info";

                  DATABASE_URL = pg.url;
                  REDIS_URL = "redis://localhost:${toString redisPort}";
                  BACKUP_DIR = "/data/backup";

                  # tailscaled terminates TLS and proxies plaintext to `port`,
                  # so the app only sees the public scheme and client address
                  # through `X-Forwarded-*`. Without both of these, session
                  # cookies lose their `Secure` attribute and logins fail.
                  TRUST_PROXY = "true";
                  CORS_ORIGIN = "https://${fqdn}";
                };
                volumes = [
                  "${backupDir}:/data/backup:U"
                ];
              };
              unitConfig = {
                After = [
                  pg.unit
                  "${redisName}.service"
                ];
                Requires = [
                  pg.unit
                  "${redisName}.service"
                ];
                AssertPathIsDirectory = [ backupDir ];
              };
            };
          };
        }

        (myLib.mkQuadletPostgres config pg {
          inherit podName;
          inherit (cfg) timeZone;
          image = cfg.dbImage;
          dataPath = "/home/postgres/pgdata/data";
          # Upstream's tuning, verbatim: the decompression cap keeps a single
          # DML transaction bounded, the lock table has to be big enough for a
          # Tautulli import to touch many chunks at once, and 150 connections
          # leaves headroom over the app's self-sizing pool.
          settings = [
            "timescaledb.license=timescale"
            "timescaledb.max_tuples_decompressed_per_dml_transaction=100000"
            "max_locks_per_transaction=4096"
            "timescaledb.telemetry_level=off"
            "max_connections=150"
          ];
          containerConfig = {
            shmSize = "512m";
            ulimits = [ "nofile=65536:65536" ];
          };
        })

        (mkQuadletDynamicEnvironment {
          containerName = svc;
          variables = {
            JWT_SECRET = "cat ${lib.escapeShellArg cfg.jwtSecretFile}";
            COOKIE_SECRET = "cat ${lib.escapeShellArg cfg.cookieSecretFile}";
          };
        })

        # Tracearr ships its own Tailscale integration, but it is configured
        # through its web UI and holds its own node state, which neither the
        # tagged auth key nor the rest of this repo's services do. Sidecar for
        # consistency.
        (mkTailscaleQuadletExposure svc { https = port; })

        (lib.mkIf cfg.backupToNAS (buildBackupScriptForDir backupDir { inherit (cfg) timeZone; }))
      ]
    );
}
