# See https://github.com/gf3/dotfiles/blob/master/.bash_prompt for ideas for coloring (maybe in ZSH/Bash cross-compatible way?)
function prompt_pwd() {
  if osx; then
    extended="-E"
  else
    extended="-re"
  fi

  echo `pwd|sed -e "s|$HOME|~|"|sed -E "s|([^/])[^/]+/|\1/|g"`
}

function precmd() {
  PS1="$(user_at_host)$(prompt_pwd) ♪ "
}
