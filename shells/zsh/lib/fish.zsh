source $FRESH_PATH/build/vendor/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# source $FRESH_PATH/build/vendor/history-substring-search/zsh-history-substring-search.zsh

autoload -U up-line-or-beginning-search
zle -N up-line-or-beginning-search

autoload -U down-line-or-beginning-search
zle -N down-line-or-beginning-search

# bind UP and DOWN arrow keys to prefix search history (diff keys for diff terms)
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# bind SHIFT-UP / SHIFT-DOWN & PAGE UP / PAGE DOWN to search history matching current contents (non-prefix)
bindkey '^[[5~' history-substring-search-up
bindkey '^[[1;2A' history-substring-search-up
bindkey '^[[6~' history-substring-search-down
bindkey '^[[1;2B' history-substring-search-down

# Bind control + LEFT and RIGHT arrow keys to jump by word
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# bind P and N for EMACS mode
bindkey -M emacs '^P' history-substring-search-up
bindkey -M emacs '^N' history-substring-search-down

# bind k and j for VI mode
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
