# Environment variables
. "$HOME/.local/share/dotfiles/hm-session-vars.sh"

# Only source this once
if [[ -z "${__HM_ZSH_SESS_VARS_SOURCED-}" ]]; then
  export __HM_ZSH_SESS_VARS_SOURCED=1
  export AUTOPAIR_INIT_INHIBIT="1"
  export ZVM_INIT_MODE="sourcing"
fi

[ -d /opt/homebrew/bin ] && eval "$(/opt/homebrew/bin/brew shellenv)"

source ~/.orbstack/shell/init.zsh 2>/dev/null || :

# https://mise.jdx.dev/dev-tools/shims.html#how-to-add-mise-shims-to-path
eval "$(mise activate zsh --shims)"

