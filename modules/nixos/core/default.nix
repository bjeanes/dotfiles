{ lib, ... }:
{
  imports = (lib.snowfall.fs.get-non-default-nix-files ./.);

  config = {
    programs.git.enable = true;

    programs.zsh = {
      enable = true;
      syntaxHighlighting.enable = true;
    };
  };
}
