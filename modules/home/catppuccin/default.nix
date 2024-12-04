{ lib, ... }:
{
  catppuccin = {
    enable = lib.mkDefault true;
    flavor = lib.mkDefault "macchiato";
  };

  programs.wezterm.extraConfig = # lua
    ''
      config.color_scheme = "Catppuccin Macchiato"
    '';

}
