{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "publish-dotfiles";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.findutils
    pkgs.git
  ];
  text = builtins.readFile ./render.sh + builtins.readFile ./publish-dotfiles.sh;
}
