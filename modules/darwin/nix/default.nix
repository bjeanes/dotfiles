{
  config,
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
        # The guest fetches its own substitutes (builders-use-substitutes), so
        # it needs the same caches this host has, or it rebuilds from source
        # anything that only lives in one of ours. Inherited rather than
        # repeated so modules/shared/nix stays the one place a cache is added.
        # mkForce, not merge: the guest profile defines cache.nixos.org too, and
        # a plain merge leaves it listed twice, so nix queries it twice per path.
        nix.settings = lib.mapAttrs (_: lib.mkForce) {
          substituters = lib.unique config.nix.settings.substituters;
          trusted-public-keys = lib.unique config.nix.settings.trusted-public-keys;
        };

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
