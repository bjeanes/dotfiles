# https://cmacr.ae/blog/managing-firefox-on-macos-with-nix/

{ pkgs, ... }: {
  config = {
    programs.firefox = {
      enable = true;
      package = pkgs.firefox-bin;

      # These don't work in Darwin because home-manager just skips applying the policies altogether
      # https://github.com/nix-community/home-manager/blob/04213d1ce4221f5d9b40bcee30706ce9a91d148d/modules/programs/firefox/mkFirefoxModule.nix#L219-L220
      # This might be because nixpkgs doesn't have working Firefox builds for Darwin.autoConfig
      #
      # I am working around nixpkgs with https://github.com/bandithedoge/nixpkgs-firefox-darwin and working around not
      # being able to set policies with a custom overlay.
      policies = { };
    };
  };
}
