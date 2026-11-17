# Serves Immich's shared links, and uploads to them, without making Immich
# itself public
{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  svc = "immich-public-proxy";
  version = "4.2.0";
  cfg = config.homelab.services.${svc};
  immich = config.homelab.services.immich;

  # Immich's pod, so that both reach it on localhost
  podName = "immich-pod";
  immichPort = 2283;
  port = 3000;
  uploadPort = 3001;

  publicUrl = "https://${cfg.hostName}.${config.homelab.tailscale.tailnet}";

  mkContainer =
    {
      image,
      listenPort,
      healthPath,
    }:
    {
      autoStart = true;
      containerConfig = {
        pod = config.virtualisation.quadlet.pods.${podName}.ref;
        inherit image;
        environments = {
          IMMICH_URL = "http://localhost:${toString immichPort}";
          PUBLIC_BASE_URL = publicUrl;
          IPP_PORT = toString listenPort;
        };

        # Upstream's compose hardening
        readOnly = true;
        dropCapabilities = [ "ALL" ];
        noNewPrivileges = true;

        healthCmd = "curl -sf -m 4 -o /dev/null http://localhost:${toString listenPort}${healthPath}";
        healthInterval = "30s";
        healthTimeout = "5s";
        healthRetries = 3;
      };
    };
in
{
  options.homelab.services.${svc} =
    flake.lib.mkHomelabServiceOptions config svc {
      image = "ghcr.io/alangrainger/immich-public-proxy:${version}";
      hostName = "photo-drop";
      dashboard.enable = false;
      # Services can't be Funnelled
      exposeAs = "sidecar";
    }
    // {
      uploadImage = lib.mkOption {
        default = "ghcr.io/alangrainger/immich-public-proxy-upload:${version}";
        type = lib.types.str;
        description = "OCI image for ${svc}'s visitor uploads";
      };
    };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = immich.enable;
            message = "${svc} runs in Immich's pod, so it needs `homelab.services.immich.enable`";
          }
        ];

        virtualisation.quadlet.containers = {
          ${svc} = mkContainer {
            inherit (cfg) image;
            listenPort = port;
            healthPath = "/share/healthcheck";
          };

          "${svc}-upload" = mkContainer {
            image = cfg.uploadImage;
            listenPort = uploadPort;
            healthPath = "/healthcheck";
          };
        };
      }

      (flake.lib.mkTailscaleQuadletExposure pkgs config svc {
        inherit podName;
        https = {
          "/" = port;
          # The upload service builds its links from the prefix, which
          # Tailscale would otherwise strip
          "/upload/" = "http://localhost:${toString uploadPort}/upload/";
        };
        funnel = [ 443 ];
      })
    ]
  );
}
