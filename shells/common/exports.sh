command -v vim &>/dev/null && editor="$(which vim)"
command -v nvim &>/dev/null && editor="$(which nvim)"

if command -v ag &>/dev/null; then
  # Ignore anything in .gitignore but still list other hidden files (e.g. .env)
  export FZF_DEFAULT_COMMAND="ag -l --hidden --ignore .git/"
fi

# Many editor integrations (linters, language server, etc) mess up Phoenix auto
# reloading by compiling changed files themselves (causing Phoenix to think
# that the live version is up-to-date).
#
# Each tool has various work-arounds to make this work, but the simplest thing
# (for editors started from the terminal) is to simply change the environment
# everything runs under by default.
editor="env MIX_ENV=test $editor"

export EDITOR="$editor -f"
export VISUAL="$editor"

# Enable shell history in IEx and Erlang REPLs
export ERL_AFLAGS="-kernel shell_history enabled"

export TERM=xterm-256color
export CLICOLOR=1

export HISTSIZE=1000000
export HISTIGNORE="clear:bg:fg:cd:cd -:exit:date:w:* --help"

export GOPATH="$HOME/Code/Go"
PATH="$PATH:$GOPATH/bin"
