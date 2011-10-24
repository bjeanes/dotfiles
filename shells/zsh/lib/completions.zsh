#
# completion tweaking
#
autoload -U compinit; compinit

compdef hub=git

# Group matches and describe groups
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:descriptions' format $'\e[01;33m -- %d --\e[0m'
zstyle ':completion::complete:cd:' tag-order local-directories path-directories
zstyle ':completion:*' group-name ''

# Don't auto-complete internal functions (ones prefixed with _)
zstyle ':completion:*:functions' ignored-patterns '_*'

# Verbose completions
zstyle ':completion:*' verbose yes

# Use menu ()
zstyle ':completion:*' menu select

# Leaving these out until I know what they do or how to change them

# zstyle ':completion:*:options' description 'yes'
# zstyle ':completion:*:options' auto-description '%d'
# zstyle ':completion:*:messages' format $'\e[01;35m -- %d --\e[0m'
# zstyle ':completion:*:warnings' format $'\e[01;31m -- No Matches Found --\e[0m'

# zstyle ':completion:*' verbose yes
# zstyle ':completion:*' use-cache on
# zstyle ':completion:*' users resolve
# hosts=(${${${${(f)"$(<$HOME/.ssh/known_hosts)"}:#[0-9]*}%%\ *}%%,*})
# zstyle ':completion:*:hosts' hosts $hosts

# # use dircolours in completion listings
# zstyle ':completion:*' list-colors ${(s.:.)LSCOLORS}
#
# # allow approximate matching
# zstyle ':completion:*' completer _complete _match _approximate
# zstyle ':completion:*:match:*' original only
# zstyle ':completion:*:approximate:*' max-errors 1 numeric
# zstyle ':completion:*:*:(^rm):*:*files' ignored-patterns \
#     '*?.(o|c~|zwc)' '*?~'
