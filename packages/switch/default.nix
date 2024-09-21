{ lib
, pkgs
, stdenv
, ...
}:
pkgs.writeShellApplication {
  name = "switch";

  runtimeInputs = [
    pkgs.snowfallorg.flake
  ] ++ lib.optionals stdenv.isDarwin [ pkgs.darwin-rebuild ];

  text = /* bash */ ''
    flake switch "$@"
  '';
}
