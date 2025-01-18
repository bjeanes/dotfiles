{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}:
let
  # Home Manager module doesn't have nice ergonomics for keybindings. This is
  # lifted from the now-deprecated https://github.com/clo4/ghostty-hm-module
  toGhosttyKeybindings = lib.generators.toKeyValue {
    listsAsDuplicateKeys = true;
    mkKeyValue = key: value: "keybind = ${key}=${value}";
  };

  # https://github.com/nix-community/home-manager/issues/6295
  ghosttyPkg =
    if pkgs.stdenv.isDarwin then
      (pkgs.writeShellScriptBin "gostty-mock" "true")
    else
      inputs.ghostty.packages.${system}.default;
in
{
  options.programs.ghostty.keybindings = lib.mkOption {
    type = with lib.types; attrsOf str;
    default = { };
  };

  config = lib.mkMerge [
    {
      programs.kitty = {
        enable = true;
        extraConfig = ''
          background_opacity 0.8
          background_blur 10
          enable_audio_bell no
        '';
      };

      programs.ghostty = {
        enable = true;
        package = ghosttyPkg;
        enableBashIntegration = true;
        enableZshIntegration = true;

        # HM sources this from the package, but on darwin this is just a dummy package, so it errors
        installBatSyntax = !pkgs.stdenv.isDarwin;

        settings = {
          background-blur-radius = 20;
          window-theme = "dark";
          #window-theme = system;
          background-opacity = 0.9;
          minimum-contrast = 1.1;
          shell-integration-features = "sudo";
        };

        keybindings = {
          "global:ctrl+`" = "toggle_quick_terminal";
        };
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
    }
    (
      let
        cfg = config.programs.ghostty;
      in
      (lib.mkIf cfg.enable {
        xdg.configFile."ghostty/config".text = toGhosttyKeybindings cfg.keybindings;
      })
    )
  ];
}
