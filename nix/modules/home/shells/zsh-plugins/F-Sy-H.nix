{ pkgs, ... }:
{
  programs.zsh = {
    plugins = [
      {
        name = "F-Sy-H";
        src = "${pkgs.zsh-f-sy-h}/share/zsh/site-functions";
      }
    ];
  };
}
