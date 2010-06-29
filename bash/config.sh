alias reload="source ~/.bashrc"

export PS1="\w ♪ "

if [ $system_name == 'Darwin' ]; then
  source $DOT_FILES/bash/terminal
fi

if [ -f /etc/bash_completion ]; then
  . /etc/bash_completion
# else
  # . $DOT_FILES/bash/bash_completion
fi

# readline settings
bind "set completion-ignore-case on" 
bind "set bell-style none" # No bell, because it's damn annoying
bind "set show-all-if-ambiguous On" # this allows you to automatically show completion without double tab-ing

shopt -s checkwinsize
shopt -s histappend
shopt -s cdable_vars
shopt -s globstar 2>/dev/null # Bash 4 and above only

complete -C $DOT_FILES/bash/rake-completion.rb -o default rake}