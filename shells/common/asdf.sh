if [ -f "$HOME/.asdf/asdf.sh" ]; then
  . $HOME/.asdf/asdf.sh
elif command -v brew &>/dev/null && [ -f "`brew --prefix`/opt/asdf/libexec/asdf.sh" ]; then
  . `brew --prefix`/opt/asdf/libexec/asdf.sh
fi

# Colemak alias
command -v asdf &>/dev/null && alias arst=asdf
