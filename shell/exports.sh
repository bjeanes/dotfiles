export PATH="/usr/local/mysql/bin/:$PATH"
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
export PATH="$PATH:/usr/local/jruby/bin"

# Use single quotes here to lazy evaluate the $EDITOR variable (as it changes later if on OS X)
export EDITOR='nano -w'
export GEM_OPEN_EDITOR='$EDITOR'
export GIT_EDITOR='$EDITOR'
export VISUAL='$EDITOR'

export IRBRC="$HOME/.irbrc"
export JEWELER_OPTS="--rspec --gemcutter --rubyforge --reek --roodi"

export TERM=xterm-color
export GREP_OPTIONS='--color=auto' GREP_COLOR='1;32'
export CLICOLOR=1

export HISTSIZE=1000000
