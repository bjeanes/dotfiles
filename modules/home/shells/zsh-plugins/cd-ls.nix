{ inputs, ... }:
{
  programs.zsh = {

    plugins = [
      {
        name = "cd-ls";
        src = inputs.zsh-cd-ls;
      }
    ];
  };
}
