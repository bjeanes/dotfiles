{ lib, ... }:
let
  myHosts = {
    nas.hostnames = [
      "10.144.70.159" # ZeroTier
      "100.120.117.10" # Tailscale
      "10.10.10.10" # local
    ];

    tumtum.hostnames = [
      "10.144.119.0" # ZeroTier
      "100.87.76.44" # Tailscale
      "10.10.10.46" # local
    ];

    borogrove.hostnames = [
      "10.144.230.45" # ZeroTier
    ];

    "hass homeassistant home-assistant".hostnames = [
      "10.144.245.56" # ZeroTier
      "100.80.108.14" # Tailscale
      "10.10.10.73" # local
    ];

    bandersnatch.hostnames = [
      "10.144.79.92" # ZeroTier
    ];

    jabberwocky.hostnames = [
      "10.144.6.239" # ZeroTier
    ];
  };
in
{
  config = {
    programs.ssh = {
      enable = true;
      addKeysToAgent = "confirm 1h";
      includes = [
        "~/.orbstack/ssh/config"
        "~/.ssh/config.d/*"
      ];

      matchBlocks =
        with lib;
        let
          allHosts = naturalSort (
            concatLists (mapAttrsToList (name: { hostnames, ... }: [ name ] ++ hostnames) myHosts)
          );
        in
        {
          ${concatStringsSep " " allHosts} = {
            forwardAgent = true;
          };
        }
        // concatMapAttrs (
          host:
          {
            hostnames ? [ ],
          }:
          {
            ${host} = {
              hostname = (builtins.head hostnames);
            };
          }
        ) myHosts;
    };
  };
}
