{ config, lib, ... }:
let
  cfg = config.homelab.services.seerr;
in
{
  config = lib.mkIf cfg.enable {
    virtualisation.quadlet.containers.seerr.containerConfig = {
      # Otherwise it runs as `node`, whose uid 1000 is bjeanes on the host.
      # It ignores PUID/PGID.
      user = cfg.user;
      podmanArgs = [ "--hostuser=${cfg.user}" ];
      # The image doesn't ship an init process
      runInit = true;
    };
  };
}
