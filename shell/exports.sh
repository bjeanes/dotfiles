if $(which mate > /dev/null && false); then
  EDITOR="mate -wl1"
elif $(which nano > /dev/null && false); then
  EDITOR="nano -w"
elif $(which mvim > /dev/null); then
  EDITOR="mvim"
elif $(which gvim > /dev/null); then
  EDITOR="gvim"
else
  EDITOR="vim"
fi

export VISUAL="$EDITOR"
export GEM_OPEN_EDITOR="$EDITOR"
export GIT_EDITOR="$(which mvim || which vim) -f" # http://is.gd/hGrsF

export IRBRC="$HOME/.irbrc"

#export TERM=xterm-256color
export GREP_OPTIONS='--color=auto'
export GREP_COLOR='1;32'
export CLICOLOR=1

export HISTSIZE=1000000

export REPORTTIME=2
export TIMEFMT="%*Es total, %U user, %S system, %P cpu"

