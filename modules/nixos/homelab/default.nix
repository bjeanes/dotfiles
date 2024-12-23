{ lib, config, ... }:
let
  # https://github.com/NixOS/nixpkgs/blob/1c6e20d/nixos/modules/config/locale.nix#L11C2-L13C5
  nospace = str: lib.filter (c: c == " ") (lib.stringToCharacters str) == [ ];
  timezone = lib.types.nullOr (lib.types.addCheck lib.types.str nospace) // {
    description = "null or string without spaces";
  };
in
{
  imports = (lib.snowfall.fs.get-non-default-nix-files-recursive ./.);

  options = {
    homelab = {
      timeZone = lib.mkOption {
        default = config.time.timeZone;
        type = timezone;
        description = ''
          Time zone to be used for the homelab services
        '';
      };

      user = lib.mkOption {
        default = null;
        type = with lib.types; nullOr str;
        description = ''
          User to run the homelab services as
        '';
      };

      group = lib.mkOption {
        default = "homelab";
        type = lib.types.str;
        description = ''
          Group to run the homelab services as
        '';
      };

      tailscale = {
        enable = lib.mkOption {
          default = true;
          type = lib.types.bool;
          description = "Enable Tailscale for homelab services";
        };
      };
    };
  };
}
