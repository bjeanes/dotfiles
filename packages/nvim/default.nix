{
  lib,
  pkgs,
  inputs,
  system,
  ...
}:
let
  inherit (inputs) nixvim;

  nixvim' = nixvim.legacyPackages.${system};
in
nixvim'.makeNixvimWithModule {
  inherit pkgs;
  extraSpecialArgs = {
    myLib = inputs.self.lib;
  };
  module = {
    # This means I can't use `default.nix` as a filename later, because there
    # doesn't seem to be a version that is "all files recursive except THIS
    # default.nix"
    imports = (inputs.self.lib.nixFilesRecursive ./.);
  };
}
