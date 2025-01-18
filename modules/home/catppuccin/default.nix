{ lib, ... }:
{
  catppuccin = {
    enable = lib.mkDefault true;
    flavor = lib.mkDefault "mocha";
  };

  programs.wezterm.extraConfig = # lua
    ''
      config.color_scheme = "Catppuccin Mocha"
    '';

  programs.bat.config.theme = "Catppuccin Mocha";

  programs.ghostty.settings.theme = "dark:catppuccin-mocha,light:catppuccin-latte";
}
