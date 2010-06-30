export EDITOR='mate -wl1'
export PATH="/Library/PostgreSQL8/bin/:$PATH"
CDPATH="${CDPATH}:${HOME}/Code/Mocra/:${HOME}/Code/Personal:${HOME}/Sites/Mocra/:${HOME}/Sites/Personal/"

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