PATH="/usr/local/bin:/usr/local/sbin:/usr/X11/bin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH}"
CDPATH=".:${HOME}"

source $DOT_FILES/shells/$CURRENT_SHELL/config.*sh
source $DOT_FILES/shells/exports.sh
source $DOT_FILES/shells/aliases.sh
source $DOT_FILES/shells/functions.sh
source $DOT_FILES/shells/prompt.sh
source $DOT_FILES/shells/git.sh

[[ `uname -s` == 'Darwin' ]] && source $DOT_FILES/shells/osx.sh
