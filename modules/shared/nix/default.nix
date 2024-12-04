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
        substituters = [
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };
    };
  };
}
