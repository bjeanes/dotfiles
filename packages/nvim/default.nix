{ lib
, inputs
, system
, pkgs
, ...
}:
let
  inherit (inputs) khanelivim;
in
khanelivim.packages.${system}.default.extend {
  imports = lib.snowfall.fs.get-non-default-nix-files-recursive ./.;

  # TODO: overrides:
  # - https://github.com/khaneliman/khanelivim/blob/42dbca505535e8da3950658766fa9003da121de7/packages/khanelivim/options.nix#L63C5-L64C1
}
