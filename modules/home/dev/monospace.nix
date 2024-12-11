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

  programs.kitty = {
    font = {
      package = pkgs.nerd-fonts.meslo-lg;
      name = code-font;
      size = 13;
    };
  };

  programs.wezterm.extraConfig = /* lua */ ''
    config.font = wezterm.font_with_fallback({
      "${code-font}",
    })
  '';

  fonts.fontconfig.enable = true;
  fonts.fontconfig.defaultFonts.monospace = [
    code-font
  ];

}
