{ lib, ... }:
{
  programs.atuin.enable = lib.mkForce false;
}
