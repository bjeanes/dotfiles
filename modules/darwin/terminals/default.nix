{ lib, ... }:
{
  config = {
    home-manager.sharedModules = [
      {
        programs.ghostty.enable = lib.mkDefault true;
        programs.kitty.enable = lib.mkDefault true;
        programs.wezterm.enable = lib.mkDefault true;
      }
    ];
  };
}
