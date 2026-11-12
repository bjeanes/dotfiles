{ lib, ... }:
{
  catppuccin = {
    autoEnable = lib.mkDefault true;
    enable = lib.mkDefault true;
    flavor = lib.mkDefault "macchiato";
  };

  programs.bat.config.theme = "Catppuccin Macchiato";

  programs.ghostty.settings.theme = "dark:catppuccin-macchiato,light:catppuccin-latte";
}
