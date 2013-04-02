which hub &>/dev/null && alias git='hub'

alias ll='ls -lah'
alias l='ls'
alias b='cd -'
alias cdr='cd ./$(git rev-parse --show-cdup)'

# useful command to find what you should be aliasing:
alias profileme="history | awk '{print \$2}' | awk 'BEGIN{FS=\"|\"}{print \$1}' | sort | uniq -c | sort -n | tail -n 20 | sort -nr"

# rails stuff
alias sc="if [ -f script/console ]; then script/console; else script/rails console; fi"
alias ss="if [ -f script/server ]; then script/server; else script/rails server; fi"
alias gen='if [ -f script/generate ]; then script/generate; else script/rails generate; fi'
alias webshare='python -c "import SimpleHTTPServer;SimpleHTTPServer.test()"'

alias pubkey="cat $HOME/.ssh/*.pub"
alias colorslist="set | egrep 'COLOR_\w*'"  # lists all the colors

alias jsonify='python -mjson.tool'

if [ -n "$SSH_CONNECTION" ]; then
  # Never open GUI vim when SSHd into a box
  alias mvim='vim'
  alias gvim='vim'
fi
