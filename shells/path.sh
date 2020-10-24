## TODO: remove duplicates when appending/prepending
## TODO: Ideally, __prepend will add (or move existing) entry to front while __append will add (or move)
##       entry to back. Anything unmentioned should stay in the middle and anything mentioned should not
##       be doubled up with system-provided.

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

[ -d '/usr/local/bin' ]     && __prepend_path "PATH" "/usr/local/bin"
[ -d '/usr/local/sbin' ]    && __prepend_path "PATH" "/usr/local/sbin"
[ -d '/opt/local/bin' ]     && __prepend_path "PATH" "/opt/local/bin"
[ -d '/opt/local/sbin' ]    && __prepend_path "PATH" "/opt/local/sbin"
[ -d '/opt/bin' ]           && __prepend_path "PATH" "/opt/bin"
[ -d '/opt/sbin' ]          && __prepend_path "PATH" "/opt/sbin"
[ -d "$HOME/bin" ]          && __prepend_path "PATH" "$HOME/bin"
[ -d "$HOME/.local/bin" ]   && __prepend_path "PATH" "$HOME/.local/bin"
[ -d "$HOME/.cargo/bin" ]   && __prepend_path "PATH" "$HOME/.cargo/bin"
[ -d "$HOME/.emacs.d/bin" ] && __prepend_path "PATH" "$HOME/.emacs.d/bin"
[ -d "$HOME/.dotfiles/bin" ] && __prepend_path "PATH" "$HOME/.dotfiles/bin"
[ -d '/usr/X11/bin' ]       && __append_path "PATH" "/usr/X11/bin"
[ -d '/usr/bin' ]           && __append_path "PATH" "/usr/bin"
[ -d '/usr/sbin' ]          && __append_path "PATH" "/usr/sbin"
[ -d '/bin' ]               && __append_path "PATH" "/bin"
[ -d '/sbin' ]              && __append_path "PATH" "/sbin"
