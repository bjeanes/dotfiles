{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}:
let
  cfg = config.programs.ghostty;

  # Home Manager module doesn't have nice ergonomics for keybindings. This is
  # lifted from the now-deprecated https://github.com/clo4/ghostty-hm-module
  toGhosttyKeybindings = lib.generators.toKeyValue {
    listsAsDuplicateKeys = true;
    mkKeyValue = key: value: "keybind = ${key}=${value}";
  };

  # https://github.com/nix-community/home-manager/issues/6295
  ghosttyPkg =
    if pkgs.stdenv.hostPlatform.isDarwin then
      (pkgs.writeShellScriptBin "gostty-mock" "true")
    else
      inputs.ghostty.packages.${system}.default;
in
{
  options.programs.ghostty.keybindings = lib.mkOption {
    type = with lib.types; attrsOf str;
    default = { };
  };

  # Opt-in; see terminal.nix.
  config = {
    programs.ghostty = {
      package = ghosttyPkg;
      enableBashIntegration = true;
      enableZshIntegration = true;

      # HM sources this from the package, but on darwin this is just a dummy package, so it errors
      installBatSyntax = !pkgs.stdenv.hostPlatform.isDarwin;

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

    xdg.configFile."ghostty/config" = lib.mkIf cfg.enable {
      text = toGhosttyKeybindings cfg.keybindings;
    };
  };
}
