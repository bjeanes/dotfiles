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

  # https://github.com/nix-community/home-manager/issues/6295
  ghosttyPkg =
    if pkgs.stdenv.hostPlatform.isDarwin then
      (pkgs.writeShellScriptBin "ghostty-mock" "true")
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
        shell-integration-features = "sudo,ssh-env,ssh-terminfo,title";
        keybind = [
          "global:ctrl+`=toggle_quick_terminal"
        ];
      };
    };
  };
}
