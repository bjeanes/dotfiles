# Only source this once.
if [ -n "${__HM_SESS_VARS_SOURCED-}" ]; then return; fi
export __HM_SESS_VARS_SOURCED=1

export EDITOR="nvim"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range :500 {}'"
export FZF_DEFAULT_OPTS_FILE="$HOME/.local/share/dotfiles/catppuccin-fzf/catppuccin-fzf-macchiato.rc"
export GLAMOUR_STYLE="$HOME/.local/share/dotfiles/catppuccin-glamour/catppuccin-macchiato.json"
export LG_CONFIG_FILE="$HOME/.local/share/dotfiles/catppuccin-lazygit/macchiato/mauve.yml,$HOME/Library/Application Support/lazygit/config.yml"
export OP_PLUGIN_ALIASES_SOURCED="1"
export STARSHIP_CONFIG="$HOME/.config/starship.toml"
export VISUAL="nvim"
export PATH="$HOME/bin${PATH:+:}$PATH"
if [ -z "$SSH_CONNECTION" ]; then
  export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
fi

# reset TERM with new TERMINFO available (if any)
export TERM="$TERM"
