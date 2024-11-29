{ ... }: {
  config = {
    programs.kitty = {
      enable = true;
      extraConfig = ''
        background_opacity 0.8
        background_blur 10
        enable_audio_bell no
      '';
      themeFile = "Tomorrow_Night_Eighties";
    };

    programs.wezterm = {
      enable = true;
      extraConfig = builtins.readFile ./wezterm.lua;
    };
  };
}
