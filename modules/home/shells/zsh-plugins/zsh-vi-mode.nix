{ config, pkgs, ... }:
{
  programs.zsh = {
    plugins = [
      {
        name = "zsh-vi-mode";
        src = "${pkgs.zsh-vi-mode}/share/zsh-vi-mode";
      }
    ];

    # auto-pair compatibility
    #
    # https://github.com/jeffreytse/zsh-vi-mode/issues/185#issuecomment-1476720559
    sessionVariables = {
      ZVM_INIT_MODE = "sourcing";
      AUTOPAIR_INIT_INHIBIT = "1";
    };
  };
}
