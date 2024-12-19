{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
{
  config = {
    home.shellAliases = {
      g = "git";
      l = "ls";
      ll = "ls -la";
      cat = "bat";
      lg = "lazygit";
      cd = "z";
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autocd = true;
      autosuggestion.enable = true;

      zsh-abbr.enable = true;
      zsh-abbr.abbreviations =
        with lib;
        config.home.shellAliases
        // config.programs.zsh.shellAliases
        // (concatMapAttrs (n: v: { "git ${n}" = "git ${v}"; }) (
          filterAttrs (n: v: !hasPrefix "!" v) config.programs.git.aliases
        ));

      plugins = [
        {
          name = "fzf-tab";
          src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
        }
        {
          name = "F-Sy-H";
          src = "${pkgs.zsh-f-sy-h}/share/zsh/site-functions";
        }
        {
          name = "cd-ls";
          src = inputs.zsh-cd-ls;
        }
        {
          name = "zsh-ssh";
          src = inputs.zsh-ssh;
        }
        {
          name = "zsh-autopair";
          src = inputs.zsh-autopair;
        }
      ];
    };
    programs.bash = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true;
    };
    programs.starship.enable = true;

    programs.zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

    programs.eza = {
      enable = true;
      git = true;
      icons = "auto";
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

    # By default, this integration also hooks into shell ^R for history search, but atuin is better
    # and fortunately appears to take precedence when both are enabled
    programs.fzf.enable = true;
    programs.fzf.enableZshIntegration = true;
    programs.fzf.enableBashIntegration = true;
    programs.fzf.fileWidgetOptions = [
      "--preview '${pkgs.bat}/bin/bat --color=always --style=numbers --line-range :500 {}'"
    ];

  };
}
