# I always want to be in a Tmux session when SSHing into a box.

# If we aren't already in Tmux or emacs, set it up
if command -v tmux &>/dev/null && [ "$SSH_CONNECTION" -a -z "$TMUX" -a -z "$INSIDE_EMACS" -a -z "$EMACS" -a -z "$VIM" -a -z "$VIMRUNTIME" ]; then
    if tty >/dev/null; then
        if ! tmux has-session -t login 2>/dev/null; then
            tmux attach-session -t login
        else
            tmux new-session -s login
        fi

        # When Tmux exits, we exit
        exit
    fi
fi
