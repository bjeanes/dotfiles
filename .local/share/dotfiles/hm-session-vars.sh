# Only source this once.
if [ -n "$__HM_SESS_VARS_SOURCED" ]; then return; fi
export __HM_SESS_VARS_SOURCED=1

export EDITOR="nvim"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range :500 {}'"
export FZF_DEFAULT_OPTS="--color bg:#1e1e2e,bg+:#313244,fg:#cdd6f4,fg+:#cdd6f4,header:#cba6f7,hl:#cba6f7,hl+:#cba6f7,info:#cba6f7,marker:#cba6f7,pointer:#cba6f7,prompt:#cba6f7,spinner:#f5e0dc"
export GLAMOUR_STYLE="$HOME/.local/share/dotfiles/catppuccin-glamour/catppuccin-mocha.json"
export LG_CONFIG_FILE="$HOME/.local/share/dotfiles/catppuccin-lazygit/mocha/mauve.yml,$HOME/Library/Application Support/lazygit/config.yml"
export OP_PLUGINS_SOURCED="1"
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
export STARSHIP_CONFIG="$HOME/.config/starship.toml"
export VISUAL="nvim"

