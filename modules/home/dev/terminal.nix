{ lib, ... }: {
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
      extraConfig = lib.mkMerge [
        (lib.mkBefore /* lua */ ''
          local config = wezterm.config_builder()
          local act = wezterm.action

          -- TODO: Keep this here until this issue is resolved: https://github.com/wez/wezterm/issues/5990
          config.front_end = "WebGpu"
        '')
        (builtins.readFile ./wezterm/keys.lua)
        (builtins.readFile ./wezterm/wezterm.lua)
        (lib.mkAfter /* lua */ "return config")
      ];

    };
  };
}
