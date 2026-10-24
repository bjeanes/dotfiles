# Echoes requests back, headers included, to see what tailscaled forwards
{
  config,
  lib,
  ...
}:
let
  svc = "whoami";
  cfg = config.homelab.services.${svc};
in
{
  options.homelab.services.${svc} = {
    enable = lib.mkEnableOption svc;

    image = lib.mkOption {
      default = "docker.io/traefik/${svc}:latest";
      type = lib.types.str;
      description = "OCI image for ${svc}";
    };

    hostName = lib.mkOption {
      default = svc;
      type = lib.types.str;
      description = "Tailscale Service name to expose ${svc} as";
    };

    port = lib.mkOption {
      default = 8099;
      type = lib.types.port;
      description = "Port on 127.0.0.1 that ${svc} is published on";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.quadlet.containers.${svc} = {
      autoStart = true;
      containerConfig = {
        image = cfg.image;
        autoUpdate = "registry";
        publishPorts = [ "127.0.0.1:${toString cfg.port}:80" ];
      };
    };

    homelab.tailscale.serve.services.${cfg.hostName}.https = cfg.port;
  };
}
