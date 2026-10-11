{ flake, ... }:
{
  imports = [ flake.homeModules.default ];

  home.stateVersion = "24.11";
}
