{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "stitch-dotfiles";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.git
    pkgs.gnused
  ];
  text = builtins.readFile ./stitch-dotfiles.sh;
}
