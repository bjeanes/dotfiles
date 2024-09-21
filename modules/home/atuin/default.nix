# Shell history recording + UI
{ pkgs, ... }: {
  config = {
    programs.atuin.enable = true;
    programs.atuin.enableZshIntegration = true;
    programs.atuin.enableBashIntegration = true;
    programs.atuin.settings = {
      dialect = "uk";
      filter_mode_shell_up_key_binding = "session";
      workspaces = true;
      style = "compact";
      inline_height = 20;
      enter_accept = false;
      ctrl_n_shortcuts = true;

      stats.common_prefix = [
        "sudo"
        "time"
      ];
    };
  };
}
