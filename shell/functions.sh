function f() { find * -name $1; }
function p() {
  cd $* && m
}
function m() {
  if [ -n "$*" ]; then
    files=$*
  else
    files=.
  fi
  mate -l1 $files 2>/dev/null
}

function extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xvjf $1        ;;
            *.tar.gz)    tar xvzf $1     ;;
            *.bz2)       bunzip2 $1       ;;
            *.rar)       unrar x $1     ;;
            *.gz)        gunzip $1     ;;
            *.tar)       tar xvf $1        ;;
            *.tbz2)      tar xvjf $1      ;;
            *.tgz)       tar xvzf $1       ;;
            *.zip)       unzip $1     ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1    ;;
            *)           echo "'$1' cannot be extracted via >extract<" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Custom "command not found" handling (ala method_missing):

# Zsh
function command_not_found_handler() {
  /usr/bin/env ruby $DOT_FILES/misc/method_missing.rb $*
}

# Bash (call Zsh version)
function command_not_found_handle() {
  command_not_found_handler $*
  return $?
}