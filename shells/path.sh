function __prepend_path {
  if [ -z "$(eval echo \$$1)" ]; then
    eval "$1=\"$2\""
  else
    eval "$1=\"$2:\$$1\""
  fi
}

function __append_path {
  if [ -z "$(eval echo \$$1)" ]; then
    eval "$1=\"$2\""
  else
    eval "$1=\"\$$1:$2\""
  fi
}

[ -d "$HOME/bin" ]          && __prepend_path "PATH" "$HOME/bin"
[ -d "$HOME/.cargo/bin" ]   && __prepend_path "PATH" "$HOME/.cargo/bin"
[ -d "$HOME/.emacs.d/bin" ] && __prepend_path "PATH" "$HOME/.emacs.d/bin"
[ -d "$DOT_FILES/bin" ]     && __prepend_path "PATH" "$DOT_FILES/bin"
[ -d '/usr/local/bin' ]     && __append_path "PATH" "/usr/local/bin"
[ -d '/usr/local/sbin' ]    && __append_path "PATH" "/usr/local/sbin"
[ -d '/opt/local/bin' ]     && __append_path "PATH" "/opt/local/bin"
[ -d '/opt/local/sbin' ]    && __append_path "PATH" "/opt/local/sbin"
[ -d '/usr/X11/bin' ]       && __append_path "PATH" "/usr/X11/bin"
[ -d '/usr/bin' ]           && __append_path "PATH" "/usr/bin"
[ -d '/usr/sbin' ]          && __append_path "PATH" "/usr/sbin"
[ -d '/bin' ]               && __append_path "PATH" "/bin"
[ -d '/sbin' ]              && __append_path "PATH" "/sbin"
