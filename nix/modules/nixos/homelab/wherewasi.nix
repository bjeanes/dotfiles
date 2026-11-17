{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  svc = "wherewasi";
in
{
  options.homelab.services.${svc} =
    flake.lib.mkHomelabServiceOptions config svc {
      image = "ghcr.io/bjeanes/wherewasi-replay:latest";
      hostName = svc;
      dashboard.description = "Re-living the 2010 trip around Europe";
      dashboard.group = "Home";
      # Services can't be Funnelled
      exposeAs = "sidecar";
      backupDescription = "Back up ${svc}'s database and trip file to legacy location on NAS";
    }
    // {
      immichApiKeyFile =
        flake.lib.mkSecretFileOption config svc "immich-api-key"
          "File containing a read-only Immich API key for ${svc}";
    };

  config =
    let
      myLib = flake.lib;
      cfg = config.homelab.services.${svc};
      immich = config.homelab.services.immich;

      podName = "${svc}-pod";
      fqdn = "${cfg.hostName}.${config.homelab.tailscale.tailnet}";
      port = 3000;

      # The database and trip file are copied in by hand, as the app's README
      # describes
      dataDir = "${cfg.configDir}/data";
      cacheDir = "${cfg.configDir}/cache";
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          systemd.tmpfiles.rules = [
            "d ${cfg.configDir} 0700 - - - -"
            "d ${dataDir} 0700 - - - -"
            "d ${cacheDir} 0700 - - - -"
            # Thumbnails and faces are re-fetched from Immich on demand,
            # unlike the GeoNames download beside them
            "d ${cacheDir}/photos 0700 - - 30d -"
            "d ${cacheDir}/people 0700 - - 30d -"
          ];

          virtualisation.quadlet = {
            pods.${podName} = { };

            containers.${svc} = {
              autoStart = true;
              containerConfig = {
                pod = config.virtualisation.quadlet.pods.${podName}.ref;
                autoUpdate = "registry";
                image = cfg.image;
                environments = {
                  TZ = cfg.timeZone;
                  HOST = myLib.listenAddressFor cfg;
                  PORT = toString port;
                  ORIGIN = "https://${fqdn}";

                  DATABASE_PATH = "/data/wherewasi.db";
                  TRIP_CONFIG = "/data/trip.json";
                  MEDIA_CACHE_DIR = "/cache";
                  IMMICH_URL = "https://${immich.hostName}.${config.homelab.tailscale.tailnet}";
                };
                volumes = [
                  "${dataDir}:/data"
                  "${cacheDir}:/cache"
                ];
              };
              unitConfig.AssertPathIsDirectory = [
                dataDir
                cacheDir
              ];
            };
          };
        }

        (myLib.mkQuadletDynamicEnvironment pkgs config {
          containerName = svc;
          variables.IMMICH_API_KEY = "tr -d '\\r\\n' < ${lib.escapeShellArg cfg.immichApiKeyFile}";
        })

        (myLib.mkTailscaleQuadletExposure pkgs config svc {
          https = port;
          funnel = [ 443 ];
        })

        (lib.mkIf cfg.backupToNAS (
          myLib.buildBackupScriptForDir pkgs svc dataDir { inherit (cfg) timeZone; }
        ))
      ]
    );
}
