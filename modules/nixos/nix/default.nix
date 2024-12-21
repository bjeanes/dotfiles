{ pkgs, ... }:
{
  nix.gc.dates = "weekly";

  users.users.root.shell = pkgs.zsh;

}
