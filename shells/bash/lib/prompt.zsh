function prompt_pwd() {
  if osx; then
    extended="-E"
  else
    extended="-re"
  fi

  echo `pwd|sed -e "s|$HOME|~|"|sed -E "s|([^/])[^/]+/|\1/|g"`
}
