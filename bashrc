export PATH="/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/:$PATH"
export PATH="/Library/PostgreSQL8/bin/:$PATH"     
export PATH="/usr/local/mysql/bin/:$PATH"
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
export IRBRC="$HOME/.irbrc"

export COLOR_NC='\e[0m' # No Color
export COLOR_WHITE='\e[1;37m'
export COLOR_BLACK='\e[0;30m'
export COLOR_BLUE='\e[0;34m'
export COLOR_LIGHT_BLUE='\e[1;34m'
export COLOR_GREEN='\e[0;32m'
export COLOR_LIGHT_GREEN='\e[1;32m'
export COLOR_CYAN='\e[0;36m'
export COLOR_LIGHT_CYAN='\e[1;36m'
export COLOR_RED='\e[0;31m'
export COLOR_LIGHT_RED='\e[1;31m'
export COLOR_PURPLE='\e[0;35m'
export COLOR_LIGHT_PURPLE='\e[1;35m'
export COLOR_BROWN='\e[0;33m'
export COLOR_YELLOW='\e[1;33m'
export COLOR_GRAY='\e[0;30m'
export COLOR_LIGHT_GRAY='\e[0;37m'
alias colorslist="set | egrep 'COLOR_\w*'"  # lists all the colors

export PS1='\h:\W \u$(__git_ps1 " \[${COLOR_RED}\](%s)\[${COLOR_NC}\]")\$ '

export TERM=xterm-color
export GREP_OPTIONS='--color=auto' GREP_COLOR='1;32'
export CLICOLOR=1
export EDITOR='/usr/bin/mate -w'
export GIT_EDITOR=$EDITOR
export VISUAL=$EDITOR
# sets title of window to be user@host
export PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*} ${PWD}"; echo -ne "\007"' 

alias gem='sudo gem' # sick of always forgetting sudo
alias ls='ls -G'
alias ll='ls -lah'
alias ..='cd ..;' # can then do .. .. .. to move up multiple directories.
alias ...='.. ..'
alias g='grep -i'  #case insensitive grep
alias ducks='du -cks * | sort -rn|head -11' # Lists the size of all the folders$
alias top='top -o cpu'
alias systail='tail -f /var/log/system.log'
# useful command to find what you should be aliasing:
alias profileme="history | awk '{print \$2}' | awk 'BEGIN{FS=\"|\"}{print \$1}' | sort | uniq -c | sort -n | tail -n 20 | sort -nr"

# rails stuff
alias log='tail -f -0 ./log/*.log'
alias ss='ruby ./script/server'
alias sc='ruby ./script/console'
alias cdm='cap deploy deploy:migrate'
alias model='script/generate model'
alias controller='script/generate controller'
alias migration='script/generate migration'
alias migrate='rake db:migrate'
alias rollback='rake db:rollback'

alias startpg='sudo /Library/StartupItems/PostgreSQL/PostgreSQL start'

alias hidefile='/usr/bin/SetFile -a "V"'
alias showfile='/usr/bin/SetFile -a "v"'

# Gem Doc
export GEMDIR=`gem env gemdir`
gemdoc() {
  open $GEMDIR/doc/`$(which ls) $GEMDIR/doc | grep $1 | sort | tail -1`/rdoc/index.html
}
_gemdocomplete() {
  COMPREPLY=($(compgen -W '$(`which ls` $GEMDIR/doc)' -- ${COMP_WORDS[COMP_CWORD]}))
  return 0
}

complete -o default -o nospace -F _gemdocomplete gemdoc
complete -C ~/.rake-completion.rb -o default rake


# readline settings
bind "set completion-ignore-case on" 
bind "set bell-style none" # No bell, because it's damn annoying
bind "set show-all-if-ambiguous On" # this allows you to automatically show completion without double tab-ing

# Turn on advanced bash completion if the file exists (get it here: http://www.caliban.org/bash/index.shtml#completion)
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

if [ ! -f ~/.dirs ]; then
	touch ~/.dirs
fi

alias show='cat ~/.dirs'
save (){
	command sed "/!$/d" ~/.dirs > ~/.dirs1; \mv ~/.dirs1 ~/.dirs; echo "$@"=\"`pwd`\" >> ~/.dirs; source ~/.dirs ; 
}
source ~/.dirs  # Initialization for the above 'save' facility: source the .dirs file
shopt -s cdable_vars # set the bash option so that no '$' is required when using the above facility

# history (bigger size, no duplicates, always append):
export HISTCONTROL=erasedups
export HISTSIZE=10000
shopt -s histappend

alias h='history|g'
