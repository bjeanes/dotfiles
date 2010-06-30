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

# colors
function color {
  local reset='\e[0m'
  local white='\e[1;37m'
  local black='\e[0;30m'
  local blue='\e[0;34m'
  local light_blue='\e[1;34m'
  local green='\e[0;32m'
  local light_green='\e[1;32m'
  local cyan='\e[0;36m'
  local light_cyan='\e[1;36m'
  local red='\e[0;31m'
  local light_red='\e[1;31m'
  local purple='\e[0;35m'
  local light_purple='\e[1;35m'
  local brown='\e[0;33m'
  local yellow='\e[1;33m'
  local gray='\e[0;30m'
  local light_gray='\e[0;37m'
  
  local chosen="$(eval echo \$$1)" 
  
  if [ $CURRENT_SHELL = 'zsh' ]; then
    echo "%{$chosen%}"
  else
    printf "$chosen"
  fi
}

function prompt_char {
    git branch >/dev/null 2>/dev/null && echo '±' && return
    hg root >/dev/null 2>/dev/null && echo '☿' && return
    # echo '○'
    echo '♪'
}

function prompt_color() {
  if [ "$USER" = "root" ]; then 
    echo red
  else
    if [ -n "$SSH_TTY" ]; then
      echo blue
    else
      echo green
    fi
  fi
}

function prompt_vcs_if_bash() {
  if [ $CURRENT_SHELL = 'bash' ]; then
    local vcs="$(eval echo $RPS1)"
    [[ "$vcs" != "" ]] && echo " $vcs"
  fi
}

RPS1='$(${HOME}/.config/misc/vcprompt.py -f $(color red)‹%b:%h›$(color reset))'
PS1="\$(color blue)\$(prompt_pwd)\$(prompt_vcs_if_bash) \$(color \$(prompt_color))\$(prompt_char)\$(color reset) "
