which vim &>/dev/null && editor="$(which vim)"
which nvim &>/dev/null && editor="$(which nvim)"

# Many editor integrations (linters, language server, etc) mess up Phoenix auto
# reloading by compiling changed files themselves (causing Phoenix to think
# that the live version is up-to-date).
#
# Each tool has various work-arounds to make this work, but the simplest thing
# (for editors started from the terminal) is to simply change the environment
# everything runs under by default.
editor="env MIX_ENV=editor $editor"

export EDITOR="$editor -f"
export VISUAL="$editor"

export TERM=xterm-256color
export CLICOLOR=1

export HISTSIZE=1000000
export HISTIGNORE="clear:bg:fg:cd:cd -:exit:date:w:* --help"

export GOPATH="$HOME/Code/Go"
PATH="$PATH:$GOPATH/bin"
