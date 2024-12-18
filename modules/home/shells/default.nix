{ pkgs, ... }:
{
  config = {
    home.shellAliases = {
      g = "git";
      l = "ls";
      ll = "ls -la";
      cat = "${pkgs.bat}/bin/bat";
      lg = "${pkgs.lazygit}/bin/lazygit";
      cd = "z";
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autocd = true;
      autosuggestion.enable = true;

      plugins = [
        {
          name = "fzf-tab";
          src = "${pkgs.zsh-fzf-tab}/share/fzf-tab";
        }
        {
          name = "F-Sy-H";
          src = "${pkgs.zsh-f-sy-h}/share/zsh/site-functions";
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
