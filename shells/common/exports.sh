which vim &>/dev/null && editor="$(which vim)"
which nvim &>/dev/null && editor="$(which nvim)"

export EDITOR="$editor -f"
export VISUAL="$editor"

export TERM=xterm-256color
export CLICOLOR=1

export HISTSIZE=1000000
export HISTIGNORE="clear:bg:fg:cd:cd -:exit:date:w:* --help"

export GOPATH="$HOME/Code/Go"
PATH="$PATH:$GOPATH/bin"
