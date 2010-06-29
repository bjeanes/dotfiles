PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/git/bin:/usr/local/mongodb/bin:/usr/local/pgsql/bin:/usr/X11/bin:/opt/local/bin
CDPATH=".:${HOME}"

source $DOT_FILES/shell/exports.sh
source $DOT_FILES/shell/aliases.sh
source $DOT_FILES/shell/save-directory.sh
source $DOT_FILES/git/git.sh

[[ `uname -s` == 'Darwin' ]] && source $DOT_FILES/shell/osx.sh

VCPROMPT=~/.config/misc/vcprompt.py