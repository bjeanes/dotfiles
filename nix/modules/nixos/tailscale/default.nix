{ config, ... }:
{
  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth-server.path;
    authKeyParameters.ephemeral = false;
    openFirewall = true;
    extraUpFlags = [
      "--advertise-tags=tag:home,tag:server"
    ];
  };

  # Tailscale service overwrites /etc/resolved.conf which makes podman/docker
  # containers later trying to run their own tailscale connections fail because
  # they can't resolve the API server properly so get stuck in a boot loop.
  #
  # https://github.com/tailscale/tailscale/issues/4254
  services.resolved.enable = true;
}
