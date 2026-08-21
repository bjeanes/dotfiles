{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  svc = "tracearr";
  tsnet = "griffin-climb.ts.net";
in
{
  options.homelab.services.${svc} = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable ${svc}";
    };

    image = lib.mkOption {
      default = "ghcr.io/connorgallopo/${svc}:latest";
      type = lib.types.str;
      description = "OCI image for ${svc}";
    };

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

    hostName = lib.mkOption {
      default = svc;
      type = lib.types.str;
      description = "Tailnet hostname to expose ${svc} as";
    };

    jwtSecretFile = lib.mkOption {
      default = config.age.secrets."${svc}-jwt-secret".path;
      type = lib.types.str;
      description = "File containing the key ${svc} signs auth tokens with";
    };

    cookieSecretFile = lib.mkOption {
      default = config.age.secrets."${svc}-cookie-secret".path;
      type = lib.types.str;
      description = "File containing the key ${svc} signs cookies with";
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

    backupToNAS = lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = "Back up ${svc}'s database dumps to legacy location on NAS";
    };
  };

  config =
    let
      myLib = lib.${namespace};
      cfg = config.homelab.services.${svc};
      buildBackupScriptForDir = myLib.buildBackupScriptForDir pkgs svc;
      mkTailscaleQuadletContainer = myLib.mkTailscaleQuadletContainer pkgs config;
      mkQuadletDynamicEnvironment = myLib.mkQuadletDynamicEnvironment pkgs config;

      inherit (config.virtualisation.quadlet) pods volumes;

      podName = "${svc}-pod";
      fqdn = "${cfg.hostName}.${tsnet}";

      dbName = "${svc}-db";
      redisName = "${svc}-redis";

      port = 3000;
      dbPort = 5432;
      redisPort = 6379;

      dbUser = svc;
      dbDatabase = svc;
      dbPassword = svc;

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

            volumes."${svc}-pgdata" = { };
            volumes."${svc}-redisdata" = { };

            containers.${dbName} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                image = cfg.dbImage;
                # Upstream's tuning, verbatim: the decompression cap keeps a
                # single DML transaction bounded, the lock table has to be big
                # enough for a Tautulli import to touch many chunks at once, and
                # 150 connections leaves headroom over the app's self-sizing pool.
                exec = [
                  "postgres"
                  "-c"
                  "listen_addresses=127.0.0.1"
                  "-c"
                  "timescaledb.license=timescale"
                  "-c"
                  "timescaledb.max_tuples_decompressed_per_dml_transaction=100000"
                  "-c"
                  "max_locks_per_transaction=4096"
                  "-c"
                  "timescaledb.telemetry_level=off"
                  "-c"
                  "max_connections=150"
                ];
                environments = {
                  TZ = cfg.timeZone;
                  POSTGRES_USER = dbUser;
                  POSTGRES_DB = dbDatabase;
                  POSTGRES_PASSWORD = dbPassword;
                };
                volumes = [
                  "${volumes."${svc}-pgdata".ref}:/home/postgres/pgdata/data"
                ];
                shmSize = "512m";
                ulimits = [ "nofile=65536:65536" ];
                # `Notify=healthy` makes the unit reach READY only once
                # `pg_isready` passes, which is what lets `tracearr.service`
                # order itself behind a database that will actually accept a
                # connection rather than one whose process merely exists.
                notify = "healthy";
                healthCmd = "pg_isready -U ${dbUser}";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 5;
              };
              # First boot runs initdb before the healthcheck can pass.
              serviceConfig.TimeoutStartSec = "300";
            };

            containers.${redisName} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                image = cfg.redisImage;
                exec = [
                  "redis-server"
                  "--appendonly"
                  "yes"
                  # As above: only the pod needs to reach this.
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
                  HOST = "127.0.0.1";
                  PORT = toString port;
                  LOG_LEVEL = "info";

                  DATABASE_URL = "postgres://${dbUser}:${dbPassword}@localhost:${toString dbPort}/${dbDatabase}";
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
                  "${dbName}.service"
                  "${redisName}.service"
                ];
                Requires = [
                  "${dbName}.service"
                  "${redisName}.service"
                ];
                AssertPathIsDirectory = [ backupDir ];
              };
            };
          };
        }

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
        (mkTailscaleQuadletContainer "${svc}-tailscale" {
          inherit podName;
          hostname = cfg.hostName;
          https = port;
        })

        (lib.mkIf cfg.backupToNAS (buildBackupScriptForDir backupDir { inherit (cfg) timeZone; }))
      ]
    );
}
