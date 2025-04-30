{
  system,
  lib,
  pkgs,
  ...
}:
{
  services.nix-daemon.enableSocketListener = true;

  nix = {
    enable = true;

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
}
