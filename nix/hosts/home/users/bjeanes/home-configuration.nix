{ flake, ... }:
{
  imports = [ flake.homeModules.default ];

  # The terminals are opt-in per machine (see nix/modules/home/dev/terminal.nix).
  programs.ghostty.enable = true;
  programs.kitty.enable = true;
  programs.wezterm.enable = true;

  home.stateVersion = "24.05";
}
