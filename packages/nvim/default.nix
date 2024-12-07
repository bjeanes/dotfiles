{
  lib,
  pkgs,
  inputs,
  system,
  namespace,
  ...
}:
let
  inherit (inputs) nixvim;

  nixvim' = nixvim.legacyPackages.${system};
in
nixvim'.makeNixvimWithModule {
  inherit pkgs;
  extraSpecialArgs = {
    myLib = lib.${namespace};
  };
  module = {
    # This means I can't use `default.nix` as a filename later, because there
    # doesn't seem to be a version that is "all files recursive except THIS
    # default.nix"
    imports = (lib.snowfall.fs.get-non-default-nix-files-recursive ./.);
  };
}
