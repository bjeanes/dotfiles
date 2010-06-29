alias gi='sudo gem install'
alias ll='ls -lah'
alias ..='cd ..;' # can then do .. .. .. to move up multiple directories.
alias ...='.. ..'
alias g='grep -i'  #case insensitive grep
alias h='history|g'
alias ducks='du -cks * | sort -rn |head -11' # Lists the size of all the folders
alias top='top -o cpu'
alias et="$EDITOR ."

alias sprof="reload"

alias home="cd $HOME" # the tilde is too hard to reach
alias systail='tail -f -n0 /var/log/system.log'
alias aptail='tail -f -n0 /var/log/apache*/*log'
alias l='ls'
alias b='cd -'

alias c='clear' # shortcut to clear your terminal

# useful command to find what you should be aliasing:
alias profileme="history | awk '{print \$2}' | awk 'BEGIN{FS=\"|\"}{print \$1}' | sort | uniq -c | sort -n | tail -n 20 | sort -nr"

# rails stuff
alias log='tail -f -0 ./log/*.log'
alias ss='ruby ./script/server'
alias sc='ruby ./script/console'
alias gen='script/generate'
alias migration='script/generate migration'
alias migrate='rake db:migrate && rake db:migrate RAILS_ENV=test'
alias rollback='rake db:rollback'
alias r='rake'
alias webshare='python -c "import SimpleHTTPServer;SimpleHTTPServer.test()"'

alias pubkey="cat $HOME/.ssh/*.pub"
alias colorslist="set | egrep 'COLOR_\w*'"  # lists all the colors

function f() { find * -name $1; }
function p() {
  cd $* && m
}
function m() {
  if [ -n "$*" ]; then
    files=$*
  else
    files=.
  fi
  mate -l1 $files 2>/dev/null
}

function extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xvjf $1        ;;
            *.tar.gz)    tar xvzf $1     ;;
            *.bz2)       bunzip2 $1       ;;
            *.rar)       unrar x $1     ;;
            *.gz)        gunzip $1     ;;
            *.tar)       tar xvf $1        ;;
            *.tbz2)      tar xvjf $1      ;;
            *.tgz)       tar xvzf $1       ;;
            *.zip)       unzip $1     ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1    ;;
            *)           echo "'$1' cannot be extracted via >extract<" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

if [ `uname -s` = "Darwin" ]; then
  function prompt_pwd() {
    if [ "$PWD" != "$HOME" ]; then
      printf "%s" `echo $PWD|sed -e 's|/private||' -e "s|^$HOME|~|" -e 's-/\(\.\{0,1\}[^/]\)\([^/]*\)-/\1-g'`
      echo $PWD|sed -e 's-.*/\.\{0,1\}[^/]\([^/]*$\)-\1-'
    else
      echo '~'
    fi
  }
else # defined two for diff systems because Fish did (not entirely sure why)
  function prompt_pwd() {
    case "$PWD" in
      $HOME)
        echo '~'
        ;;
      *)
        printf "%s" `echo $PWD|sed -e "s|^$HOME|~|" -e 's-/\(\.\{0,1\}[^/]\)\([^/]*\)-/\1-g'`
        echo $PWD|sed -n -e 's-.*/\.\{0,1\}.\([^/]*\)-\1-p'
        ;;
    esac
  }
fi