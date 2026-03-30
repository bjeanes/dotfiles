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

typeset -U path cdpath fpath manpath
for profile in ${(z)NIX_PROFILES}; do
  fpath+=($profile/share/zsh/site-functions $profile/share/zsh/$ZSH_VERSION/functions $profile/share/zsh/vendor-completions)
done

ZSH_SSH_AWK="gawk"
# Add plugin directories to PATH and fpath
plugin_dirs=(
  zsh-vi-mode zsh-ssh zsh-autopair fzf-tab cd-ls F-Sy-H
)
for plugin_dir in "${plugin_dirs[@]}"; do
  path+="$HOME/.zsh/plugins/$plugin_dir"
  fpath+="$HOME/.zsh/plugins/$plugin_dir"
done
unset plugin_dir plugin_dirs


autoload -U compinit && compinit
source $HOME/.local/share/dotfiles/zsh-autosuggestions/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history)


eval "$(zoxide init zsh )"

# Source plugins
plugins=(
  zsh-vi-mode/zsh-vi-mode.plugin.zsh zsh-ssh/plugin.zsh
  zsh-autopair/zsh-autopair.plugin.zsh fzf-tab/fzf-tab.plugin.zsh
  cd-ls/cd-ls.plugin.zsh F-Sy-H/F-Sy-H.plugin.zsh
)
for plugin in "${plugins[@]}"; do
  [[ -f "$HOME/.zsh/plugins/$plugin" ]] && source "$HOME/.zsh/plugins/$plugin"
done
unset plugin plugins

# History options should be set in .zshrc and after oh-my-zsh sourcing.
# See https://github.com/nix-community/home-manager/issues/177.
HISTSIZE="10000"
SAVEHIST="10000"

HISTFILE="$HOME/.zsh_history"
mkdir -p "$(dirname "$HISTFILE")"

if [[ $options[zle] = on ]]; then
  source <(fzf --zsh)
fi

source "$HOME/.local/share/dotfiles/catppuccin-zsh-syntax-highlighting/catppuccin_mocha-zsh-syntax-highlighting.zsh"

# Set shell options
set_opts=(
  HIST_FCNTL_LOCK HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY autocd
  NO_APPEND_HISTORY NO_EXTENDED_HISTORY NO_HIST_EXPIRE_DUPS_FIRST
  NO_HIST_FIND_NO_DUPS NO_HIST_IGNORE_ALL_DUPS NO_HIST_SAVE_NO_DUPS
)
for opt in "${set_opts[@]}"; do
  setopt "$opt"
done
unset opt set_opts

eval "$(mise activate zsh)"

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

if [[ $TERM != "dumb" ]]; then
  eval "$(starship init zsh)"
fi

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
  autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
  kitty-integration
  unfunction kitty-integration
fi

if [[ -n $GHOSTTY_RESOURCES_DIR ]]; then
  source "$GHOSTTY_RESOURCES_DIR"/shell-integration/zsh/ghostty-integration
fi

eval "$(direnv hook zsh)"

alias -- cat=bat
alias -- cd=z
alias -- eza='eza --icons auto --git'
alias -- g=git
alias -- jj='jj --config-file=$HOME/.jj.local.toml'
alias -- l=ls
alias -- la='eza -a'
alias -- lg=lazygit
alias -- ll='ls -la'
alias -- lla='eza -la'
alias -- ls=eza
alias -- lt='eza --tree'
alias -- vimdiff='nvim -d'