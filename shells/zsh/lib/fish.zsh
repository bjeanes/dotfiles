source $FRESH_PATH/build/vendor/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# source $FRESH_PATH/build/vendor/history-substring-search/zsh-history-substring-search.zsh

# bind UP and DOWN arrow keys
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Bind control + LEFT and RIGHT arrow keys to jump by word
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# bind P and N for EMACS mode
bindkey -M emacs '^P' history-substring-search-up
bindkey -M emacs '^N' history-substring-search-down

# bind k and j for VI mode
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
