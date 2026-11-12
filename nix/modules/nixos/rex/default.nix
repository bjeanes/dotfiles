{ config, lib, ... }:
let
  port = 7297;
  me = "tailscale:bjeanes@github";
in
{
  services.rex.loginServer = {
    enable = lib.mkDefault config.services.tailscale.enable;
    extraListen = [ "tailnet://:${toString port}" ];
    accounts.bjeanes.principals = [ me ];
    defaults.${me} = "bjeanes";
  };

  networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts =
    lib.mkIf config.services.rex.loginServer.enable
      [ port ];
}
