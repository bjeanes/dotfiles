{ lib, ... }:
{
  config = {
    programs.kitty = {
      enable = true;
      extraConfig = ''
        background_opacity 0.8
        background_blur 10
        enable_audio_bell no
      '';
    };

    programs.wezterm = {
      enable = true;
      extraConfig = lib.mkMerge [
        (lib.mkBefore # lua
          ''
            local config = wezterm.config_builder()
            local act = wezterm.action
          ''
        )
        (builtins.readFile ./wezterm/keys.lua)
        (builtins.readFile ./wezterm/ui.lua)
        (lib.mkAfter # lua
          "return config"
        )
      ];

    };
  };
}
