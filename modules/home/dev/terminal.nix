{ ... }: {
  config = {
    programs.kitty = {
      enable = true;
      extraConfig = ''
        background_opacity 0.8
        background_blur 10
        enable_audio_bell no
      '';
      theme = "Tomorrow Night Eighties";
    };

    programs.wezterm = {
      enable = true;
    };
  };
}
