{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  svc = "affine";
in
{
  options.homelab.services.${svc} =
    flake.lib.mkHomelabServiceOptions config svc {
      image = "ghcr.io/toeverything/${svc}:stable";
      hostName = svc;
      exposeAs = "service";
      backupDescription = "Back up ${svc}'s blobs, key and database dumps to legacy location on NAS";
    }
    // {
      dbImage = lib.mkOption {
        # Upstream's compose pins pg16. Pinned to a major version and opted out
        # of auto-update.
        default = "docker.io/pgvector/pgvector:pg16";
        type = lib.types.str;
        description = "OCI image for the PostgreSQL (with pgvector) backing ${svc}";
      };

      redisImage = lib.mkOption {
        default = "docker.io/library/redis:8-alpine";
        type = lib.types.str;
        description = "OCI image for the Redis backing ${svc}";
      };
    };

  config =
    let
      myLib = flake.lib;
      cfg = config.homelab.services.${svc};
      buildBackupScriptForDir = myLib.buildBackupScriptForDir pkgs svc;
      mkTailscaleQuadletExposure = myLib.mkTailscaleQuadletExposure pkgs config;

      inherit (config.virtualisation.quadlet) pods volumes;

      podName = "${svc}-pod";
      fqdn = "${cfg.hostName}.${config.homelab.tailscale.tailnet}";

      pg = myLib.postgresFor svc;
      redisName = "${svc}-redis";

      port = 3010;
      redisPort = 6379;

      # Uploaded blobs (images, attachments, etc)
      storageDir = "${cfg.configDir}/storage";

      # Holds `private.key`, which the predeploy script generates on first
      # start. It signs sessions and encrypts data, so it is backed up along
      # with everything else rather than regenerated.
      appConfigDir = "${cfg.configDir}/config";

      # `pg_dump`s land here, just ahead of each NAS backup. rsyncing this is
      # a real backup; rsyncing a live PGDATA is not, which is why the
      # database itself lives in a podman volume rather than under
      # `configDir`.
      backupDir = "${cfg.configDir}/backups";

      # The image runs as root and keeps all state under here
      home = "/root/.affine";
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          systemd.tmpfiles.rules = [
            "d ${cfg.configDir} 0700 root root - -"
            "d ${storageDir}    0700 root root - -"
            "d ${appConfigDir}  0700 root root - -"
            "d ${backupDir}     0700 root root - -"
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

                # Upstream runs the predeploy (key generation, schema and data
                # migrations) as a separate one-shot container ahead of the
                # server. Running it in front of the server instead means every
                # `podman auto-update` migrates before the new version serves.
                exec = [
                  "sh"
                  "-c"
                  "node ./scripts/self-host-predeploy.js && exec node ./dist/main.js"
                ];

                environments = {
                  TZ = cfg.timeZone;

                  LISTEN_ADDR = myLib.listenAddressFor cfg;
                  AFFINE_SERVER_PORT = toString port;

                  # tailscaled terminates TLS and proxies plaintext to `port`,
                  # so links, OAuth callbacks and the like need to be told the
                  # public origin.
                  AFFINE_SERVER_EXTERNAL_URL = "https://${fqdn}";
                  AFFINE_SERVER_HTTPS = "true";
                  AFFINE_SERVER_HOST = fqdn;

                  DATABASE_URL = pg.url;
                  REDIS_SERVER_HOST = "localhost";
                  REDIS_SERVER_PORT = toString redisPort;

                  # Full-text search wants a separate Manticore/Elasticsearch,
                  # which upstream's compose also leaves out.
                  AFFINE_INDEXER_ENABLED = "false";
                };
                volumes = [
                  "${storageDir}:${home}/storage"
                  "${appConfigDir}:${home}/config"
                ];

                # Gives `podman auto-update` something to roll back on. The
                # start period allows for migrations ahead of the server.
                healthCmd = "node -e \"fetch('http://127.0.0.1:${toString port}/info').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))\"";
                healthInterval = "30s";
                healthTimeout = "5s";
                healthRetries = 3;
                healthStartPeriod = "3m";
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
                AssertPathIsDirectory = [
                  storageDir
                  appConfigDir
                ];
              };
            };
          };
        }

        (myLib.mkQuadletPostgres config pg {
          inherit podName;
          inherit (cfg) timeZone;
          image = cfg.dbImage;
          # Pre-pg18 images keep PGDATA directly here
          dataPath = "/var/lib/postgresql/data";
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
