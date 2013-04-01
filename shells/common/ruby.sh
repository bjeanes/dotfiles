export GEM_OPEN_EDITOR="$editor"
export IRBRC="$HOME/.irbrc"
export RBXOPT="-Xrbc.db=/tmp/rbx -X19"
export JRUBY_OPTS="--1.9"

which=`which -a which | tail -n1` # avoid builtin

if [ -f "/usr/local/share/chruby/chruby.sh" ]; then
  source /usr/local/share/chruby/chruby.sh
  source /usr/local/share/chruby/auto.sh
  chruby 2.0.0-p0

  function current_ruby() {
    if [ "x$RUBY_ROOT" != "x" ]; then
      echo `basename $RUBY_ROOT`
    else
      return 1
    fi
  }
elif $which -s rbenv; then
  eval "$(rbenv init - $CURRENT_SHELL)"

  function current_ruby() {
    echo `rbenv version-name`
  }
elif $which -s rvm; then
  source $HOME/.rvm/scripts/rvm

  function current_ruby() {
    echo `rvm-prompt`
  }
else
  function current_ruby() {}
fi
