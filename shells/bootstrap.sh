COMMON_SHELL_FILES="$SHELL_FILES/../common"

source "$SHELL_FILES/../path.sh"
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

[ -f "$HOME/.shellrc.local" ] && source "$HOME/.shellrc.local"
