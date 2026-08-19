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

    linux-builder = {
      enable = system == "aarch64-darwin";

      # https://nixcademy.com/posts/rosetta-linux-builder-macos/
      package = pkgs.darwin.linux-builder-vz;
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
    };
    settings.trusted-users = [ "@admin" ];

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
