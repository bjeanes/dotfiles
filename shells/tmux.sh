# I always want to be in a Tmux session. Always.
#
# This creates a single always-running "login" session, and creates
# new session as needed that are bound to "login"'s window group.
# This lets me have a different terminals tabs/windows have the same tmux
# windows but be looking at different ones individually

# If we aren't in Tmux or emacs, set it up
if false && [ -z "$TMUX" -a -z "$INSIDE_EMACS" -a -z "$EMACS" ]; then
    if tty >/dev/null; then
        if which tmux 2>&1 >/dev/null; then
            if [ -z "$(tmux ls | grep 'login:')" ]; then
                tmux new-session -d -s login # Create a detached session called login
                tmux new-session -t login    # Create a *new* session bound to the same windows
            else
                last_session="$(tmux list-windows -t login | tail -n1 | cut -d: -f1)"
                tmux new-session -t login \; new-window -a -t $last_session # Create a *new* session bound to "login" and create a new window
            fi

            # When Tmux exits, we exit
            exit
        fi
    fi
fi
