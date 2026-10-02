{ lib, ... }:
{
  # Opt-in: darwin hosts default these on (modules/darwin/terminals), linux
  # workstations enable them in their home.
  config = {
    programs.kitty = {
      extraConfig = ''
        background_opacity 0.8
        background_blur 10
        enable_audio_bell no
      '';
    };

    programs.wezterm = {
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
