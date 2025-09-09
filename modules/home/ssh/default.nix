{ lib, namespace, ... }:
let
  myHosts =
    lib.concatMapAttrs
      (host: { addresses ? [ ], aliases ? [ ], ... }: {
        "${lib.concatStringsSep " " ([host] ++ aliases)}" = {
          hostnames = addresses;
        };
      })
      lib.${namespace}.hosts;
in
{
  config = {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false; # this is being deprecated but still defaults to true, so raises warnings
      includes = [
        "~/.orbstack/ssh/config" # TODO only on darwin
        "~/.ssh/config.d/*"
      ];

      matchBlocks =
        {
          "*" = {
            addKeysToAgent = "confirm 1h";
            forwardAgent = false;
          };
        } //
        (with lib;
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
        // concatMapAttrs
          (
            host:
            { hostnames ? [ ]
            ,
            }:
            {
              ${host} = {
                hostname = (builtins.head hostnames);
              };
            }
          )
          myHosts);
    };
  };
}
