{
  pkgs,
  inputs,
  system,
  ...
}:
let
  adminGroup = if pkgs.stdenv.isDarwin then "admin" else "wheel";
in
{
  config = {
    nixpkgs.config.allowUnfree = true;

    nix = {
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
        # so it never applies to root/comin builds, and ghostty ends up being
        # compiled from source. Declaring them here makes them system-wide.
        substituters = [
          "https://nix-community.cachix.org"
          "https://ghostty.cachix.org"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
        ];

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
      inputs.agenix.packages.${system}.default
    ];
  };
}
