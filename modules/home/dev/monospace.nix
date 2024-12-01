{ pkgs, ... }:
let
  code-font = "MesloLGMDZ Nerd Font Mono";
  nerdfonts = (pkgs.nerdfonts.override {
    fonts = [
      "BitstreamVeraSansMono"
      "Meslo"
      "SourceCodePro"
      "Monaspace" # Monaspace Argon, specifically
      "FiraCode"
    ];
  });
in
{
  home.packages = [
    nerdfonts
  ];

  programs.kitty = {
    font = {
      package = nerdfonts;
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
