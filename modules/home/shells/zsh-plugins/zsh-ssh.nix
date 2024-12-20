{ inputs, ... }:
{
  programs.zsh = {

    plugins = [
      {
        name = "zsh-ssh";
        src = inputs.zsh-ssh;
      }
    ];
  };
}
