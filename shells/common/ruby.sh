export GEM_OPEN_EDITOR="$editor"
export IRBRC="$HOME/.irbrc"
export RBXOPT="-Xrbc.db=/tmp/rbx -X19"
export JRUBY_OPTS="--1.9"

which rbenv &>/dev/null || return
eval "$(rbenv init - $CURRENT_SHELL)"
