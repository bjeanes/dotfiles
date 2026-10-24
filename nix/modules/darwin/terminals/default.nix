{ lib, ... }:
{
  config = {
    home-manager.sharedModules = [
      {
        programs.ghostty.enable = lib.mkDefault true;
        programs.kitty.enable = lib.mkDefault true;
        programs.wezterm.enable = lib.mkDefault true;
      }
      (
        { pkgs, ... }:
        {
          # /bin/zsh's ncurses resolves TERM before /etc/zshenv sets TERMINFO_DIRS
          # and never retries, so SSH sessions from Ghostty need it in ~/.terminfo.
          home.file.".terminfo" = {
            source = "${pkgs.ghostty-bin.terminfo}/share/terminfo";
            recursive = true;
          };
        }
      )
    ];
  };
}
