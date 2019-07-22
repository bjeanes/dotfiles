export GEM_OPEN_EDITOR="$editor"
export IRBRC="$HOME/.irbrc"
export RBXOPT="-Xrbc.db=/tmp/rbx -X19"
export JRUBY_OPTS="--1.9"

# if [ -f $SHELL_FILES/../../languages/ruby/rubyrc.rb ]; then
# 	echo setting RUBYOPT
#   export RUBYOPT="-r$SHELL_FILES/../../languages/ruby/rubyrc"
# fi

if [ -f "/usr/local/share/chruby/chruby.sh" ]; then
  source /usr/local/share/chruby/chruby.sh
  source /usr/local/share/chruby/auto.sh

  function current_ruby() {
    if [ "x$RUBY_ROOT" != "x" ]; then
      basename $RUBY_ROOT
    else
      return 1
    fi
  }
elif command -v rbenv; then
  eval "$(rbenv init - $CURRENT_SHELL)"

  function current_ruby() {
    rbenv version-name
  }
elif command -v rvm; then
  source $HOME/.rvm/scripts/rvm

  function current_ruby() {
    rvm-prompt
  }
else
  function current_ruby() {
    exit 0
  }
fi
