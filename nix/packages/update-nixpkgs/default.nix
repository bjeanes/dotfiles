{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "update-nixpkgs";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.curl
    pkgs.gawk
    pkgs.git
    pkgs.gnused
    pkgs.jq
  ];
  text = builtins.readFile ./update-nixpkgs.sh;
}
