which vim  &>/dev/null && editor="$(which vim)"
# which mvim &>/dev/null && editor="$(which mvim)"

export EDITOR="$editor -f"
export VISUAL="$editor"
export GEM_OPEN_EDITOR="$editor"
export GIT_EDITOR="$editor -f"

export IRBRC="$HOME/.irbrc"
export RBXOPT="-Xrbc.db=/tmp/rbx -X19"

export TERM=xterm-256color
export GREP_OPTIONS='--color=auto'
export GREP_COLOR='1;32'
export CLICOLOR=1

export HISTSIZE=1000000
export HISTIGNORE="clear:bg:fg:cd:cd -:exit:date:w:* --help"

export REPORTTIME=2
export TIMEFMT="%*Es total, %U user, %S system, %P cpu"

