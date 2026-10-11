{ flake, ... }:
{
  imports = [ flake.homeModules.default ];

  home.stateVersion = "26.05";
}
