{ lib, ... }:
{
  catppuccin = {
    autoEnable = lib.mkDefault true;
    enable = lib.mkDefault true;
    flavor = lib.mkDefault "macchiato";
  };

  catppuccin.bat.enable = false;
  programs.bat.config = {
    theme-light = "Catppuccin Latte";
    theme-dark = "Catppuccin Macchiato";
  };

  catppuccin.ghostty.enable = false;
  programs.ghostty.settings.theme = "dark:Catppuccin Macchiato,light:Catppuccin Latte";
}
