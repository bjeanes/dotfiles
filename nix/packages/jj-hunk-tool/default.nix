# package.nix is from https://github.com/NixOS/nixpkgs/pull/573207, moved on
# to upstream's latest commit (it has no releases); drop this once jj-hunk-tool
# is in nixpkgs
{ pkgs, ... }: pkgs.callPackage ./package.nix { }
