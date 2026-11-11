{ pkgs, ... }:
let
  code-font = "MesloLGMDZ Nerd Font Mono";
in
{
  home.packages = with pkgs.nerd-fonts; [
    bitstream-vera-sans-mono
    meslo-lg
    sauce-code-pro
    monaspace # Monaspace Argon, specifically
    fira-code
  ];

  fonts.fontconfig.enable = true;
  fonts.fontconfig.defaultFonts.monospace = [
    code-font
  ];

}
