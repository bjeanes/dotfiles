{ lib
, inputs
, system
, ...
}:
let
  inherit (inputs) khanelivim;
in
khanelivim.packages.${system}.default.extend {
  imports = lib.snowfall.fs.get-non-default-nix-files-recursive ./.;

  opts.spelllang = "en_gb,en_au";

  plugins.firenvim.enable = lib.mkForce false;
}
