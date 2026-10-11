{ inputs, pkgs, ... }:
{
  programs.zsh = {
    localVariables = {
      ZSH_SSH_AWK = "${pkgs.gawk}/bin/gawk";
    };

    plugins = [
      {
        name = "zsh-ssh";
        src = ./zsh-ssh;
        file = "plugin.zsh";
      }
    ];
  };
}
