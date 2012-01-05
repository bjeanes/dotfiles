COMMON_SHELL_FILES="$SHELL_FILES/../common"

# TODO: Remove duplicates from the PATH
PATH="/usr/local/bin:/usr/local/sbin:/usr/X11/bin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH}"

source "$SHELL_FILES/../tmux.sh"

CDPATH=".:${HOME}"
if [ -d "$HOME/Code" ]; then
  CDPATH="$CDPATH:$HOME/Code"
fi

source "$SHELL_FILES"/config.*sh

files=`ls -1 "$COMMON_SHELL_FILES"/*.sh "$SHELL_FILES"/lib/*.*sh`
for file in $files; do
  source $file
done
