source ~/.exports
# source ~/.bash_completion
source ~/.gitrc
source ~/.gemdoc
source ~/.aliases
source ~/.terminal
source ~/.save-directory

export PS1='$(__git_ps1 "\[${COLOR_RED}\](%s)\[${COLOR_NC}\] ")\$ '

# readline settings
bind "set completion-ignore-case on" 
bind "set bell-style none" # No bell, because it's damn annoying
bind "set show-all-if-ambiguous On" # this allows you to automatically show completion without double tab-ing

shopt -s checkwinsize
shopt -s histappend

complete -C ~/.rake-completion.rb -o default rake