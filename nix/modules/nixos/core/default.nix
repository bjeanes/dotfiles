{ flake, lib, ... }:
{
  imports = (flake.lib.nixFiles ./.);

  config = {
    programs.git.enable = true;

    programs.zsh = {
      enable = true;
      syntaxHighlighting.enable = true;
    };
  };
}
