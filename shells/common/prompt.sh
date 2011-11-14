function user_at_host() {
  local str

  if [[ "$USER" != "bjeanes" ]]; then
    str="$USER"

    if [[ "$USER" == "root" ]]; then
      str="$pr_red$str$pr_reset"
    fi

    str="${str}@"
  fi

  if [[ -n "$SSH_TTY" ]]; then
    str="$str$pr_blue`hostname -s`$pr_reset"
  fi

  echo $str
}

function prompt_bg_job() {
  if [ "$CURRENT_SHELL" = "zsh" ]; then
    jobs | grep '+' | awk '{print $4}'
  else
    jobs | grep '+' | awk '{print $3}'
  fi
}
