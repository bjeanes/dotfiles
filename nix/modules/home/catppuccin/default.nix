{ config, lib, ... }:
{
  catppuccin = {
    autoEnable = lib.mkDefault true;
    enable = lib.mkDefault true;
    flavor = lib.mkDefault "macchiato";
  };

  # These tools read their colours once at launch. Instead of a fixed flavour,
  # they use the terminal's 16 ANSI colours, which Ghostty's theme redefines for
  # light and dark.
  catppuccin.eza.enable = false;
  catppuccin.fzf.enable = false;
  catppuccin.lazygit.enable = false;
  catppuccin.starship.enable = false;
  programs.fzf.defaultOptions = [ "--color=16" ];

  catppuccin.bat.enable = false;
  programs.bat.config = {
    theme-light = "Catppuccin Latte";
    theme-dark = "Catppuccin Macchiato";
  };

  catppuccin.ghostty.enable = false;
  programs.ghostty.settings.theme = "dark:Catppuccin Macchiato,light:Catppuccin Latte";

  catppuccin.tmux.extraConfig =
    let
      options = ''
        set -g @catppuccin_window_text " #W"
        set -g @catppuccin_window_current_text " #W"
      '';

      # The reset unsets the plugin's window and status options, ours included.
      flavourHook = hook: flavour: ''
        set-hook -g ${hook} {
          set -g @catppuccin_flavor ${flavour}
          set -g @catppuccin_reset true
          ${options}
          run-shell ${config.catppuccin.sources.tmux.rtp}
        }
      '';
    in
    options
    + flavourHook "client-light-theme" "latte"
    + flavourHook "client-dark-theme" config.catppuccin.tmux.flavor;
}
