{ pkgs, ... }:
{
  # Darwin hosts enable this by default (modules/darwin/terminals). Linux
  # workstations opt in from their own home config.
  config = {
    programs.ghostty = {
      # ghostty-bin repackages the official signed .app; building from source
      # on darwin doesn't work (https://github.com/nix-community/home-manager/issues/6295)
      package = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
      enableBashIntegration = true;
      enableZshIntegration = true;

      settings = {
        background-blur-radius = 20;
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
