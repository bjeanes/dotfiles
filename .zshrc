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
path+="$HOME/.zsh/plugins/zsh-vi-mode"
fpath+="$HOME/.zsh/plugins/zsh-vi-mode"

path+="$HOME/.zsh/plugins/zsh-ssh"
fpath+="$HOME/.zsh/plugins/zsh-ssh"

path+="$HOME/.zsh/plugins/zsh-autopair"
fpath+="$HOME/.zsh/plugins/zsh-autopair"

path+="$HOME/.zsh/plugins/fzf-tab"
fpath+="$HOME/.zsh/plugins/fzf-tab"

path+="$HOME/.zsh/plugins/cd-ls"
fpath+="$HOME/.zsh/plugins/cd-ls"

path+="$HOME/.zsh/plugins/F-Sy-H"
fpath+="$HOME/.zsh/plugins/F-Sy-H"


autoload -U compinit && compinit
source $HOME/.local/share/dotfiles/zsh-autosuggestions/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history)


eval "$(zoxide init zsh )"

if [[ -f "$HOME/.zsh/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh" ]]; then
  source "$HOME/.zsh/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh"
fi
if [[ -f "$HOME/.zsh/plugins/zsh-ssh/plugin.zsh" ]]; then
  source "$HOME/.zsh/plugins/zsh-ssh/plugin.zsh"
fi
if [[ -f "$HOME/.zsh/plugins/zsh-autopair/zsh-autopair.plugin.zsh" ]]; then
  source "$HOME/.zsh/plugins/zsh-autopair/zsh-autopair.plugin.zsh"
fi
if [[ -f "$HOME/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh" ]]; then
  source "$HOME/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh"
fi
if [[ -f "$HOME/.zsh/plugins/cd-ls/cd-ls.plugin.zsh" ]]; then
  source "$HOME/.zsh/plugins/cd-ls/cd-ls.plugin.zsh"
fi
if [[ -f "$HOME/.zsh/plugins/F-Sy-H/F-Sy-H.plugin.zsh" ]]; then
  source "$HOME/.zsh/plugins/F-Sy-H/F-Sy-H.plugin.zsh"
fi

# History options should be set in .zshrc and after oh-my-zsh sourcing.
# See https://github.com/nix-community/home-manager/issues/177.
HISTSIZE="10000"
SAVEHIST="10000"

HISTFILE="$HOME/.zsh_history"
mkdir -p "$(dirname "$HISTFILE")"

setopt HIST_FCNTL_LOCK
unsetopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
unsetopt HIST_IGNORE_ALL_DUPS
unsetopt HIST_SAVE_NO_DUPS
unsetopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
unsetopt HIST_EXPIRE_DUPS_FIRST
setopt SHARE_HISTORY
unsetopt EXTENDED_HISTORY
setopt autocd

if [[ $options[zle] = on ]]; then
  source <(fzf --zsh)
fi

source "$HOME/.local/share/dotfiles/catppuccin-zsh-syntax-highlighting/catppuccin_mocha-zsh-syntax-highlighting.zsh"

eval "$(delta --generate-completion zsh)"

eval "$(mise activate zsh)"

. $HOME/.local/share/dotfiles/watch-defaults.sh
[ -d /opt/homebrew/bin ] && eval "$(/opt/homebrew/bin/brew shellenv)"

source "$HOME/.local/share/dotfiles/wezterm/etc/profile.d/wezterm.sh"

if [[ $TERM != "dumb" ]]; then
  eval "$(starship init zsh)"
fi

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

alias -- cargo='op plugin run -- cargo'
alias -- cat=bat
alias -- cd=z
alias -- eza='eza --icons auto --git'
alias -- g=git
alias -- gh='op plugin run -- gh'
alias -- glab='op plugin run -- glab'
alias -- heroku='op plugin run -- heroku'
alias -- jj='jj --config-file=$HOME/.jj.local.toml'
alias -- l=ls
alias -- la='eza -a'
alias -- lg=lazygit
alias -- ll='ls -la'
alias -- lla='eza -la'
alias -- ls=eza
alias -- lt='eza --tree'
alias -- tea='op plugin run -- tea'
alias -- vimdiff='nvim -d'