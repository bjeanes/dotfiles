{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    # Pass OSC 52 from programs in a pane (e.g. Claude's /copy) through to the
    # outer terminal, so copies over ssh land on the local clipboard.
    extraConfig = ''
      set -s set-clipboard on
    '';
  };
}
