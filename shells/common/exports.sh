which vim &>/dev/null && editor="$(which vim)"

export EDITOR="$editor -f"
export VISUAL="$editor"

export TERM=xterm-256color
export GREP_OPTIONS='--color=auto'
export GREP_COLOR='1;32'
export CLICOLOR=1

export HISTSIZE=1000000
export HISTIGNORE="clear:bg:fg:cd:cd -:exit:date:w:* --help"

export GOPATH="$HOME/Code/Go"
PATH="$PATH:$GOPATH/bin"
