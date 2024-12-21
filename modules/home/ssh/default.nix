{ lib, namespace, ... }:
let
  myHosts =
    lib.concatMapAttrs
      (host: { addresses ? [ ], aliases ? [ ] }: {
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
      addKeysToAgent = "confirm 1h";
      includes = [
        "~/.orbstack/ssh/config" # TODO only on darwin
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
          myHosts;
    };
  };
}
