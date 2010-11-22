[[ -f /etc/bash_completion ]] && source /etc/bash_completion

# readline settings
bind "set completion-ignore-case on" 
bind "set bell-style none" # No bell, because it's damn annoying
bind "set show-all-if-ambiguous On" # this allows you to automatically show completion without double tab-ing
bind '"\e\e[C": forward-word'
bind '"\e\e[D": backward-word'

shopt -s checkwinsize histappend cdable_vars extglob nullglob cdspell cmdhist hostcomplete

# Bash 4 and above only
shopt -s globstar autocd checkjobs 2>/dev/null 

complete -C $DOT_FILES/bash/rake-completion.rb -o default rake}

alias reload="source ~/.bashrc"
