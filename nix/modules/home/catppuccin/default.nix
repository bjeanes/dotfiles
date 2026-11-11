{ lib, ... }:
{
  catppuccin = {
    autoEnable = lib.mkDefault true;
    enable = lib.mkDefault true;
    flavor = lib.mkDefault "mocha";
  };

  programs.bat.config.theme = "Catppuccin Mocha";

  programs.ghostty.settings.theme = "dark:catppuccin-mocha,light:catppuccin-latte";
}
