{ config, ... }:
{
  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth-server.path;
    authKeyParameters.ephemeral = false;
    extraUpFlags = [
      "--advertise-tags=tag:home,tag:server"
    ];
  };
}
