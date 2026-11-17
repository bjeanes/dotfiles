# Sends Overseerr's old links on to Seerr
{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  svc = "overseerr";
  cfg = config.homelab.services.${svc};
  inherit (config.virtualisation.quadlet) pods;
  podName = "${svc}-pod";
  port = 5055;

  seerr = config.homelab.services.seerr;

  caddyfile = pkgs.writeText "${svc}-Caddyfile" ''
    :${toString port}

    bind 127.0.0.1
    redir https://${seerr.hostName}.${config.homelab.tailscale.tailnet}{uri} permanent
  '';
in
{
  options.homelab.services.${svc} =
    flake.lib.mkHomelabServiceOptions config svc {
      image = "docker.io/library/caddy:latest";
      hostName = svc;
      dashboard.enable = false;
      # Services can't be Funnelled
      exposeAs = "sidecar";
    }
    // {
      enable = lib.mkOption {
        default = seerr.enable;
        type = lib.types.bool;
        description = "Redirect ${svc}'s hostname to Seerr";
      };
    };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        virtualisation.quadlet = {
          pods.${podName} = { };

          containers.${svc} = {
            autoStart = true;
            containerConfig = {
              pod = pods.${podName}.ref;
              image = cfg.image;
              autoUpdate = "registry";
              volumes = [
                "${caddyfile}:/etc/caddy/Caddyfile:ro"
              ];
            };
          };
        };
      }

      (flake.lib.mkTailscaleQuadletExposure pkgs config svc {
        https = port;
        funnel = [ 443 ];
      })
    ]
  );
}
