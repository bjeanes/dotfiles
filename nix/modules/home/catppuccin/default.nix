{ lib, ... }:
{
  catppuccin = {
    autoEnable = lib.mkDefault true;
    enable = lib.mkDefault true;
    flavor = lib.mkDefault "macchiato";
  };

  programs.bat.config.theme = "Catppuccin Macchiato";

  catppuccin.ghostty.enable = false;
  programs.ghostty.settings.theme = "dark:Catppuccin Macchiato,light:Catppuccin Latte";
}
