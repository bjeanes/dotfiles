function __append_path {
  if [ -z "$(eval echo \$$1)" ]; then
    eval "$1=\"$2\""
  else
    eval "$1=\"\$$1:$2\""
  fi
}

[ -d "$HOME/bin" ]       && __append_path "new_path" "$HOME/bin"
[ -d "$DOT_FILES/bin" ]  && __append_path "new_path" "$DOT_FILES/bin"
[ -d '/usr/local/bin' ]  && __append_path "new_path" "/usr/local/bin"
[ -d '/usr/local/sbin' ] && __append_path "new_path" "/usr/local/sbin"
[ -d '/opt/local/bin' ]  && __append_path "new_path" "/opt/local/bin"
[ -d '/opt/local/sbin' ] && __append_path "new_path" "/opt/local/sbin"
[ -d '/usr/X11/bin' ]    && __append_path "new_path" "/usr/X11/bin"
[ -d '/usr/bin' ]        && __append_path "new_path" "/usr/bin"
[ -d '/usr/sbin' ]       && __append_path "new_path" "/usr/sbin"
[ -d '/bin' ]            && __append_path "new_path" "/bin"
[ -d '/sbin' ]           && __append_path "new_path" "/sbin"
PATH="$new_path"
