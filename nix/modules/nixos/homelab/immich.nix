{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  svc = "immich";
  version = "v3.4.0";
in
{
  options.homelab.services.${svc} =
    flake.lib.mkHomelabServiceOptions config svc {
      image = "ghcr.io/immich-app/immich-server:${version}";
      hostName = "photos";
      dashboard.description = "Photos and videos";
      dashboard.group = "Home";
      dashboard.widget = {
        type = "immich";
        # Needs the `server.statistics` permission
        secrets.key = "immich-api-key";
        settings.version = 2;
      };
    }
    // {
      mlImage = lib.mkOption {
        default = "ghcr.io/immich-app/immich-machine-learning:${version}";
        type = lib.types.str;
        description = "OCI image for ${svc}'s machine learning";
      };

      dbImage = lib.mkOption {
        # Has pgvecto.rs alongside VectorChord, which a database restored from
        # Immich < 1.133 needs to migrate from one to the other
        default = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0";
        type = lib.types.str;
        description = "OCI image for the Postgres backing ${svc}";
      };

      valkeyImage = lib.mkOption {
        default = "docker.io/valkey/valkey:8-alpine";
        type = lib.types.str;
        description = "OCI image for the Valkey backing ${svc}";
      };

      mediaDir = lib.mkOption {
        default = "/mnt/nfs/nas/media/Photos";
        type = lib.types.str;
        description = "Where ${svc} keeps uploads, thumbnails, transcodes and its database backups";
      };
    };

  config =
    let
      myLib = flake.lib;
      cfg = config.homelab.services.${svc};
      mkTailscaleQuadletExposure = myLib.mkTailscaleQuadletExposure pkgs config;

      inherit (config.virtualisation.quadlet) pods volumes;

      podName = "${svc}-pod";
      pg = myLib.postgresFor svc;
      valkeyName = "${svc}-valkey";
      mlName = "${svc}-machine-learning";

      port = 2283;
      valkeyPort = 6379;

      mediaMount = "mnt-nfs-nas-media.mount";
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          virtualisation.quadlet = {
            # The server finds machine learning by this name unless told
            # otherwise in its settings
            pods.${podName}.podConfig.addHosts = [ "${mlName}:127.0.0.1" ];

            volumes."${svc}-valkeydata" = { };
            volumes."${svc}-model-cache" = { };

            containers.${valkeyName} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                image = cfg.valkeyImage;
                exec = [
                  "valkey-server"
                  "--bind"
                  "127.0.0.1"
                ];
                environments = {
                  TZ = cfg.timeZone;
                };
                volumes = [
                  "${volumes."${svc}-valkeydata".ref}:/data"
                ];
                notify = "healthy";
                healthCmd = "valkey-cli ping";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 5;
              };
            };

            containers.${mlName} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                image = cfg.mlImage;
                environments = {
                  TZ = cfg.timeZone;
                  IMMICH_HOST = "127.0.0.1";
                };
                volumes = [
                  "${volumes."${svc}-model-cache".ref}:/cache"
                ];
              };
            };

            containers.${svc} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                image = cfg.image;
                environments = {
                  TZ = cfg.timeZone;
                  IMMICH_HOST = myLib.listenAddressFor cfg;
                  IMMICH_PORT = toString port;
                  IMMICH_MEDIA_LOCATION = "/data";
                  DB_URL = "postgresql://${pg.user}:${pg.password}@localhost:${toString pg.port}/${pg.database}";
                  REDIS_HOSTNAME = "localhost";
                  REDIS_PORT = toString valkeyPort;
                };
                devices = [ "/dev/dri:/dev/dri" ];
                volumes = [
                  "/etc/localtime:/etc/localtime:ro"
                  "${cfg.mediaDir}:/data"
                ];
              };
              unitConfig = {
                After = [
                  pg.unit
                  "${valkeyName}.service"
                  mediaMount
                ];
                Requires = [
                  pg.unit
                  "${valkeyName}.service"
                ];
                BindsTo = [ mediaMount ];
              };
            };
          };
        }

        (myLib.mkQuadletPostgres config pg {
          inherit podName;
          inherit (cfg) timeZone;
          image = cfg.dbImage;
          dataPath = "/var/lib/postgresql/data";
          settings = [ "shared_preload_libraries=vchord.so" ];
          containerConfig = {
            shmSize = "128m";
          };
        })

        (mkTailscaleQuadletExposure svc { https = port; })
      ]
    );
}
