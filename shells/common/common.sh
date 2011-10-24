PATH="/usr/local/bin:/usr/local/sbin:/usr/X11/bin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH}"
CDPATH=".:${HOME}"

source $DOT_FILES/shells/$CURRENT_SHELL/config.*sh
source $DOT_FILES/shells/common/exports.sh
source $DOT_FILES/shells/common/aliases.sh
source $DOT_FILES/shells/common/functions.sh
source $DOT_FILES/shells/common/prompt.sh
source $DOT_FILES/shells/common/git.sh

[[ `uname -s` == 'Darwin' ]] && source $DOT_FILES/shells/common/osx.sh
