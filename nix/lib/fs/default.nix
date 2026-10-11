{ lib, ... }:
let
  isModule = path: lib.hasSuffix ".nix" (toString path) && baseNameOf path != "default.nix";
in
{
  # The .nix files directly in `dir`, other than default.nix
  nixFiles =
    dir:
    map (name: dir + "/${name}") (
      builtins.attrNames (
        lib.filterAttrs (name: type: type == "regular" && isModule name) (builtins.readDir dir)
      )
    );

  # As `nixFiles`, but descending into subdirectories
  nixFilesRecursive = dir: builtins.filter isModule (lib.filesystem.listFilesRecursive dir);
}
