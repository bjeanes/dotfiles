{ flake, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  load =
    dir:
    let
      part = import dir;
    in
    if lib.isFunction part then part { inherit flake lib; } else part;
in
lib.foldr lib.recursiveUpdate { } (
  map load [
    ./fs
    ./homelab
    ./hosts
    ./misc
    ./nvim
    ./oci-containers
    ./tailscale
  ]
)
