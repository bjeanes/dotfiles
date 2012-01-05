osx || return # Only for OS X

function __setup_tmux_wrappers() {
  local wrap="reattach-to-user-namespace"
  local editors="VISUAL $(env | grep EDITOR | cut -d= -f1)"

  alias vim="$wrap vim"
  alias mvim="$wrap mvim"

  for editor in $editors; do
    eval "$editor='$wrap $(eval "echo \$$editor")'"
  done
}

if which reattach-to-user-namespace >/dev/null 2>&1; then
  # and http://writeheavy.com/2011/10/23/reintroducing-tmux-to-the-osx-clipboard.html
  [ -n "$TMUX" ] && __setup_tmux_wrappers
else
  if [ -n "$TMUX" ]; then
    echo "Installing pbpaste/pbcopy wrappers to get them working in Tmux..."
    formula="https://raw.github.com/phinze/homebrew/15e923f17f282e6dcd2b2155947163ffed7ec8c9/Library/Formula/reattach-to-user-namespace.rb"
    brew install --HEAD "$formula" --wrap-pbpaste-and-pbcopy >/dev/null 2>&1 && echo "Done." || echo "Failed."
    __setup_tmux_wrappers
  fi
fi

if [ -z "$JAVA_HOME" -a -d /System/Library/Frameworks/JavaVM.framework/Home ]; then
  export JAVA_HOME=/System/Library/Frameworks/JavaVM.framework/Home
fi

alias o='open .'

# replacement netstat cmd to find ports used by apps on OS X
alias netstat="sudo lsof -i -P"
alias pubkey="cat $HOME/.ssh/*.pub | pbcopy && echo 'Keys copied to clipboard'"

alias hidefile='/usr/bin/SetFile -a "V"'
alias showfile='/usr/bin/SetFile -a "v"'

function manpdf() { man -t $@ | open -f -a Preview; }
function osinfo() {
   x1="$(/usr/bin/sw_vers -productName)"
   x2="$(/usr/bin/sw_vers -productVersion)"
   x3="$(/usr/bin/sw_vers -buildVersion)"
   x4="$(/usr/bin/arch)"
   echo "${x1} - ${x2} - ${x3} - ${x4}"
}

function tab() {
  osascript 2>/dev/null <<EOF
    tell application "System Events"
      tell process "Terminal" to keystroke "t" using command down
    end
    tell application "Terminal"
      activate
      do script with command "cd \"$PWD\"; $*" in window 1
    end tell
EOF
}

# Minimise terminal window to Dock
function mintw() { printf "\e[2t"; return 0; }

# Send Terminal window to background
function bgtw() { printf "\e[6t"; return 0; }

function hidetw() {
   /usr/bin/osascript -e 'tell application "System Events" to set visible of some item of ( get processes whose name = "Terminal" ) to false'
   return 0
}

# positive integer test (including zero)
function positive_int() { return $(test "$@" -eq "$@" > /dev/null 2>&1 && test "$@" -ge 0 > /dev/null 2>&1); }

# move the Terminal window
function mvtw() {
   if [[ $# -eq 2 ]] && $(positive_int "$1") && $(positive_int "$2"); then
      printf "\e[3;${1};${2};t"
      return 0
   fi
   return 1
}

# resize the Terminal window
function sizetw() {
   if [[ $# -eq 2 ]] && $(positive_int "$1") && $(positive_int "$2"); then
      printf "\e[8;${1};${2};t"
      /usr/bin/clear
      return 0
   fi
   return 1
}

# full screen
function fullscreen() { printf "\e[3;0;0;t\e[8;0;0t"; /usr/bin/clear; return 0; }

# default screen
function defaultscreen() { printf "\e[8;35;150;t"; printf "\e[3;300;240;t"; /usr/bin/clear; return 0; }

# max columns
function maxc() { printf "\e[3;0;0;t\e[8;50;0t"; /usr/bin/clear; return 0; }

# max rows
function maxr() { printf "\e[3;0;0;t\e[8;0;100t"; /usr/bin/clear; return 0; }

# show number of lines & columns
function lc() { printf "lines: $(/usr/bin/tput lines)\ncolums: $(/usr/bin/tput cols)\n"; return 0; }
