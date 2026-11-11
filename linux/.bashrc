

# Commands that should be applied only for interactive shells.
[[ $- == *i* ]] || return

HISTFILESIZE=100000
HISTSIZE=10000

shopt -s histappend
shopt -s extglob
shopt -s globstar
shopt -s checkjobs

alias -- cat=bat
alias -- cd=z
alias -- eza='eza --icons auto --git'
alias -- g=git
alias -- l=ls
alias -- la='eza -a'
alias -- lg=lazygit
alias -- ll='ls -la'
alias -- lla='eza -la'
alias -- ls=eza
alias -- lt='eza --tree'
alias -- vimdiff='nvim -d'

if [[ -r "${GHOSTTY_RESOURCES_DIR}/shell-integration/bash/ghostty.bash" ]]; then
  builtin source "${GHOSTTY_RESOURCES_DIR}/shell-integration/bash/ghostty.bash"
fi

if [[ :$SHELLOPTS: =~ :(vi|emacs): ]]; then
  eval "$(fzf --bash)"
fi

# Generic handler to intercept `docker foo` to check if there is a `docker-foo` to call instead.
# Idea from https://stackoverflow.com/questions/26530234/create-your-own-docker-sub-commands
docker () {
  if [ $# -eq 0 ]; then
    command docker
    return
  fi

  local subcmd="$1"
  shift


  if command -v "docker-$subcmd" >/dev/null 2>&1; then
    docker-$subcmd "$@"
  else
    command docker $subcmd "$@"
  fi
}


# From https://stackoverflow.com/a/38077377/56690
# Fucking genius.
docker-describe() {
  if [ $# -lt 1 ]; then
    echo "Usage: docker describe CONTAINER"
    return 1
  fi

  docker inspect --format "$(cat $HOME/.local/share/dotfiles/docker-inspect-run-cmd-fmt/run.tpl)" "$1"
}

source <(COMPLETE=bash jj)

eval "$(mise activate bash)"

eval "$(devenv hook bash)"

gh() {
  op plugin run -- gh "$@";
}

cargo() {
  op plugin run -- cargo "$@";
}

heroku() {
  op plugin run -- heroku "$@";
}

tea() {
  op plugin run -- tea "$@";
}

glab() {
  op plugin run -- glab "$@";
}

source "$HOME/.local/share/dotfiles/wezterm/etc/profile.d/wezterm.sh"

function lg() {
    export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir
    command lazygit "$@"
    if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
      cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
      rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
    fi
}

if test -n "$KITTY_INSTALLATION_DIR"; then
  export KITTY_SHELL_INTEGRATION="no-rc"
  source "$KITTY_INSTALLATION_DIR/shell-integration/bash/kitty.bash"
fi

__HM_PROMPT_COMMAND="${PROMPT_COMMAND:+${PROMPT_COMMAND%;};}__hm_vte_prompt_command"
. $HOME/.local/share/dotfiles/vte/etc/profile.d/vte.sh
if [[ $(type -t __vte_prompt_command) = function ]]; then
  __hm_vte_prompt_command() {
    local old_exit_status=$?
    __vte_prompt_command
    return $old_exit_status
  }
  PROMPT_COMMAND="$__HM_PROMPT_COMMAND"
fi
unset __HM_PROMPT_COMMAND

# Inside a kitty terminal, use the `ssh` kitten so that terminfo, shell
# integration, and config are copied to the remote host. Checked at shell
# startup rather than via a static alias so that shells started outside of
# kitty (or on hosts without it) get plain `ssh`.
case "$TERM" in
  *kitty*)
    if command -v kitty >/dev/null 2>&1; then
      alias ssh='kitty +kitten ssh'
    fi
    ;;
esac

eval "$(direnv hook bash)"

if [[ $TERM != "dumb" ]]; then
  eval "$(starship init bash --print-full-init)"
fi

eval "$(zoxide init bash )"

