{
  system,
  lib,
  pkgs,
  ...
}:
{

  # h/t @khaneliman https://github.com/khaneliman/khanelinix/blob/7bf538d/modules/nixos/nix/default.nix#L13
  imports = [ (lib.snowfall.fs.get-file "modules/shared/nix/default.nix") ];

  config = {
    services.nix-daemon.enable = true;
    services.nix-daemon.enableSocketListener = true;

    nix = {
      useDaemon = true;
      configureBuildUsers = true;

      linux-builder.enable = system == "aarch64-darwin";

      gc.interval = {
        Weekday = 0;
        Hour = 0;
        Minute = 0;
      };

      optimise.interval = {
        Hour = 6;
      };
    };
  };
}
