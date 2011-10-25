ZSH="$SHELL_FILES/lib/oh-my-zsh"

plugins=(rails3 git ruby osx brew cap gem lein npm node)

if ! [ -d "$ZSH" ]; then
  echo "Cloning Oh My Zsh..."
  /usr/bin/env git clone git://github.com/robbyrussell/oh-my-zsh.git "$ZSH"
fi

source $ZSH/oh-my-zsh.sh
