{ pkgs, ... }:
let
  inherit (pkgs) lib stdenv;
in
pkgs.writeShellApplication {
  name = "switch";

  runtimeInputs = [
    pkgs.nh
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ pkgs.darwin-rebuild ];

  text = /* bash */ ''
    nh ${if stdenv.hostPlatform.isDarwin then "darwin" else "os"} switch . "$@"
  '';
}
