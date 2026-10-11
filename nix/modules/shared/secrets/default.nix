# Only the secrets this host can decrypt: agenix fails activation on any it
# cannot open, and the wg-* files are borogrove-only.
{
  config,
  flake,
  lib,
  ...
}:
let
  secretsDir = ../../../../secrets;
  rules = import (secretsDir + "/secrets.nix");
  inherit (flake.lib) hosts;

  # Absent from lib/hosts (darwin) => decrypts with my user key: keep all.
  host = hosts.${lib.toLower (config.networking.hostName or "")} or null;

  isRecipient =
    name: host == null || !(host ? hostKey) || lib.elem host.hostKey rules.${name}.publicKeys;
in
{
  age.secrets = lib.listToAttrs (
    map (name: {
      name = lib.removeSuffix ".age" name;
      # Copied out on its own so the closure doesn't hold the whole flake
      value.file = builtins.path {
        path = secretsDir + "/${name}";
        inherit name;
      };
    }) (lib.filter isRecipient (lib.attrNames rules))
  );
}
