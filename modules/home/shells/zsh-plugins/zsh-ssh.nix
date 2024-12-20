{ inputs, ... }:
{
  programs.zsh = {
    plugins = [
      {
        name = "zsh-ssh";
        src = ./zsh-ssh;
        file = "plugin.zsh";
      }
    ];
  };
}
