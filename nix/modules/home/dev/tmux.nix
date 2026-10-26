{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    mouse = true;
    focusEvents = true;
    historyLimit = 50000;
    baseIndex = 1;
    keyMode = "vi";
    # Pass OSC 52 from programs in a pane (e.g. Claude's /copy) through to the
    # outer terminal, so copies over ssh land on the local clipboard.
    extraConfig = ''
      set -s set-clipboard on
      set -s extended-keys on
      set -g renumber-windows on

      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-selection-and-cancel

      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
    '';
  };
}
