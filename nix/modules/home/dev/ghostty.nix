{ pkgs, ... }:
{
  # Opt-in; see terminal.nix.
  config = {
    programs.ghostty = {
      # ghostty-bin repackages the official signed .app; building from source
      # on darwin doesn't work (https://github.com/nix-community/home-manager/issues/6295)
      package = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;
      enableBashIntegration = true;
      enableZshIntegration = true;

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
