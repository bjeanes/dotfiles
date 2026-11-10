{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "backfill-dotfiles";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.findutils
    pkgs.git
    pkgs.gnugrep
    pkgs.gnused
    pkgs.jq
  ];
  text = builtins.readFile ../publish-dotfiles/render.sh + builtins.readFile ./backfill-dotfiles.sh;
}
