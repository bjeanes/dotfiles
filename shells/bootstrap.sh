COMMON_SHELL_FILES="$SHELL_FILES/../common"

# TODO: Remove duplicates from the PATH
PATH="/usr/local/bin:/usr/local/sbin:/usr/X11/bin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH}"

if [ -z "$TMUX" ]; then
  if which tmux 2>&1 >/dev/null; then
    if [ -z "$(tmux ls | grep 'login:')" ]; then
      tmux new-session -d -s login # Create a detached session called login
      tmux new-session -t login    # Create a *new* session bound to the same windows
    else
      last_session="$(tmux list-windows -t login | tail -n1 | cut -d: -f1)"
      tmux new-session -t login \; new-window -a -t $last_session # Create a *new* session bound to "login" and create a new window
    fi
  fi

  exit
fi


CDPATH=".:${HOME}"
if [ -d "$HOME/Code" ]; then
  CDPATH="$CDPATH:$HOME/Code"
fi

source "$SHELL_FILES"/config.*sh

files=`ls -1 "$COMMON_SHELL_FILES"/*.sh "$SHELL_FILES"/lib/*.*sh`
for file in $files; do
  source $file
done
