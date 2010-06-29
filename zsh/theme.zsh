function prompt_color() {
  if [ "$USER" = "root" ]; then 
    echo "red"
  else
    if [ -n "$SSH_TTY" ]; then
      echo "blue"
    else
      echo "green"
    fi
  fi
}

function prompt_char {
    git branch >/dev/null 2>/dev/null && echo '±' && return
    hg root >/dev/null 2>/dev/null && echo '☿' && return
    # echo '○'
    echo '♪'
}

# Prompts
ZSH_THEME_VCS_PROMPT_PREFIX="%{$fg[red]%}‹"
ZSH_THEME_VCS_PROMPT_SUFFIX="›%{$reset_color%}"
ZSH_THEME_VCS_PROMPT_FORMAT="${ZSH_THEME_VCS_PROMPT_PREFIX}%b:%h${ZSH_THEME_VCS_PROMPT_SUFFIX}"

PS1='%{$fg[blue]%}$(prompt_pwd)%{$reset_color%} %{$fg[$(prompt_color)]%}$(prompt_char)%{$reset_color%} '
RPS1='$(${VCPROMPT} -f ${ZSH_THEME_VCS_PROMPT_FORMAT})'
