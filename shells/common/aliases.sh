which hub &>/dev/null && alias git='nocorrect hub'

alias ll='ls -lah'
alias ..='cd ..;' # can then do .. .. .. to move up multiple directories.
alias ...='.. ..'
alias g='grep -i'  #case insensitive grep
alias h='history|g'
alias ducks='du -cks * | sort -rn |head -11' # Lists the size of all the folders
alias top='top -o cpu'

alias sprof="reload"
alias eprof="m $HOME/.config"

alias home="cd $HOME" # the tilde is too hard to reach
alias systail='tail -fn0 /var/log/system.log'
alias aptail='tail -fn0 /var/log/apache*/*log'
alias l='ls'
alias b='cd -'
alias cdr='cd ./$(git rev-parse --show-cdup)'

alias c='clear' # shortcut to clear your terminal

# useful command to find what you should be aliasing:
alias profileme="history | awk '{print \$2}' | awk 'BEGIN{FS=\"|\"}{print \$1}' | sort | uniq -c | sort -n | tail -n 20 | sort -nr"

# rails stuff
alias log='tail -fn0 ./log/*.log /var/log/apache*/*log'
alias sc="if [ -f script/console ]; then script/console; else script/rails console; fi"
alias ss="if [ -f script/server ]; then script/server; else script/rails server; fi"
alias gen='if [ -f script/generate ]; then script/generate; else script/rails generate; fi'
alias migration='gen migration'
alias migrate='rake db:migrate && rake db:migrate RAILS_ENV=test'
alias rollback='rake db:rollback'
alias r='rake'
alias webshare='python -c "import SimpleHTTPServer;SimpleHTTPServer.test()"'

alias pubkey="cat $HOME/.ssh/*.pub"
alias colorslist="set | egrep 'COLOR_\w*'"  # lists all the colors

alias jsonify='python -mjson.tool'

alias serial="ioreg -l | grep IOPlatformSerialNumber | cut -f 10 -d' ' | cut -d'\"' -f 2 | pbcopy && echo 'Copied to clipboard'"

if [ -n "$SSH_CONNECTION" ]; then
  # Never open GUI vim when SSHd into a box
  alias mvim='vim'
  alias gvim='vim'
fi
