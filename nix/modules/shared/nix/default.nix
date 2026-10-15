{
  lib,
  perSystem,
  pkgs,
  ...
}:
let
  adminGroup = if pkgs.stdenv.hostPlatform.isDarwin then "admin" else "wheel";
in
{
  config = {
    nix = {
      package = lib.mkDefault pkgs.nixVersions.latest;

      extraOptions = ''
        extra-nix-path = "nixpkgs=flake:nixpkgs"
        experimental-features = nix-command flakes
      '';

      gc = {
        automatic = true;
        options = "--delete-older-than 30d";
      };

      optimise = {
        automatic = true;
      };

      settings = {
        # These are also declared in flake.nix's `nixConfig`, but that is only
        # honoured for the evaluating user and only once they've accepted it --
        # so it never applies to root/comin builds. Declaring them here makes
        # them system-wide.
        substituters = [
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];

        connect-timeout = 3;
        download-attempts = 2;

        trusted-users = [
          "root"
          "@${adminGroup}"
        ];
        allowed-users = [
          "root"
          "@${adminGroup}"
          "@nixbld"
        ];
      };
    };

    environment.systemPackages = [
      perSystem.agenix.default
    ];
  };
}
