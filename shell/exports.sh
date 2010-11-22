if $(which mate); then
  EDITOR="mate -wl1"
elif $(which nano); then
  EDITOR="nano -w"
elif $(which mvim); then
  EDITOR="mvim"
elif $(which gvim); then
  EDITOR="gvim"
else
  EDITOR="vim"
fi

export GEM_OPEN_EDITOR=$EDITOR
export GIT_EDITOR=$EDITOR
export VISUAL=$EDITOR

export IRBRC="$HOME/.irbrc"
export JEWELER_OPTS="--rspec --gemcutter --rubyforge --reek --roodi"

export TERM=xterm-color
export GREP_OPTIONS='--color=auto' GREP_COLOR='1;32'
export CLICOLOR=1

export HISTSIZE=1000000
