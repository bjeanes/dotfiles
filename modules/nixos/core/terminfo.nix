{ pkgs, ... }:
{
  # So TERM=xterm-ghostty works when SSHing in from Ghostty; ncurses doesn't ship it.
  environment.systemPackages = [ pkgs.ghostty.terminfo ];
}
