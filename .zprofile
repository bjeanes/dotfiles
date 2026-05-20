[ -d /opt/homebrew/bin ] && eval "$(/opt/homebrew/bin/brew shellenv)"

source ~/.orbstack/shell/init.zsh 2>/dev/null || :

# https://mise.jdx.dev/dev-tools/shims.html#how-to-add-mise-shims-to-path
eval "$(mise activate zsh --shims)"
