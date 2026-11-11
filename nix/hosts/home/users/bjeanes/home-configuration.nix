{ flake, ... }:
{
  imports = [ flake.homeModules.default ];

  # Ghostty is opt-in per machine (see nix/modules/home/dev/ghostty.nix).
  programs.ghostty.enable = true;

  home.stateVersion = "24.05";
}
