{ inputs, ... }:
{
  programs.zsh = {

    plugins = [
      {
        name = "zsh-autopair";
        src = inputs.zsh-autopair;
      }
    ];
  };
}
