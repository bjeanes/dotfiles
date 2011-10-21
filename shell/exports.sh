export EDITOR="$(which mvim || which vim) -f" # http://is.gd/hGrsF
export VISUAL="$EDITOR"
export GEM_OPEN_EDITOR="$EDITOR"
export GIT_EDITOR="$EDITOR"

export IRBRC="$HOME/.irbrc"
export RBXOPT="-Xrbc.db=/tmp/rbx"

#export TERM=xterm-256color
export GREP_OPTIONS='--color=auto'
export GREP_COLOR='1;32'
export CLICOLOR=1

export HISTSIZE=1000000

export REPORTTIME=2
export TIMEFMT="%*Es total, %U user, %S system, %P cpu"

