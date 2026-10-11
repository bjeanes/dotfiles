{ inputs, lib, ... }:
{
  imports = (inputs.self.lib.nixFiles ./.);

  config = {
    programs.git.enable = true;

    programs.zsh = {
      enable = true;
      syntaxHighlighting.enable = true;
    };
  };
}
