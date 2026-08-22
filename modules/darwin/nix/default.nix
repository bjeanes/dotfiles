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
      maxJobs = 4;

      # Guest defaults (1 core / 3G / 20G disk) are too small to build a whole
      # NixOS closure; Borogrove's alone unpacks to ~12.5G.
      config = {
        virtualisation = lib.mkForce {
          cores = 8;
          memorySize = 12288;
          diskSize = 40960;
        };
      };
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
