{ flake, lib, ... }:
let
  myHosts = lib.concatMapAttrs (
    host:
    {
      addresses ? [ ],
      aliases ? [ ],
      ...
    }:
    {
      "${lib.concatStringsSep " " ([ host ] ++ aliases)}" = {
        hostnames = addresses;
      };
    }
  ) flake.lib.hosts;
in
{
  config = {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false; # this is being deprecated but still defaults to true, so raises warnings
      includes = [
        "~/.ssh/config.d/*"
      ];

      settings = {
        "*" = {
          AddKeysToAgent = "confirm 1h";
          ForwardAgent = false;
        };
      }
      // (
        with lib;
        let
          allHosts = naturalSort (
            concatLists (mapAttrsToList (name: { hostnames, ... }: [ name ] ++ hostnames) myHosts)
          );
        in
        {
          ${concatStringsSep " " allHosts} = {
            ForwardAgent = true;
          };
        }
        // concatMapAttrs (
          host:
          {
            hostnames ? [ ],
          }:
          {
            ${host} = {
              HostName = (builtins.head hostnames);
            };
          }
        ) myHosts
      );
    };
  };
}
