# Only source this once.
if [ -n "${__HM_SESS_VARS_SOURCED-}" ]; then return; fi
export __HM_SESS_VARS_SOURCED=1

export EDITOR="nvim"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range :500 {}'"
export FZF_DEFAULT_OPTS_FILE="$HOME/.local/share/dotfiles/catppuccin-fzf/catppuccin-fzf-mocha.rc"
export GLAMOUR_STYLE="$HOME/.local/share/dotfiles/catppuccin-glamour/catppuccin-mocha.json"
export LG_CONFIG_FILE="$HOME/.local/share/dotfiles/catppuccin-lazygit/mocha/mauve.yml,$HOME/.config/lazygit/config.yml"
export OP_PLUGIN_ALIASES_SOURCED="1"
export STARSHIP_CONFIG="$HOME/.config/starship.toml"
export VISUAL="nvim"
export PATH="$HOME/bin${PATH:+:}$PATH"
