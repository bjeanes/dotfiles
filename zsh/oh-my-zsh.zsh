export ZSH=$DOT_FILES/zsh/lib/oh-my-zsh
export ZSH_THEME="risto"
plugins=(rails3 git ruby osx brew)

if ! [ -d "$ZSH" ]; then
  echo "Cloning Oh My Zsh..."
  /usr/bin/env git clone git://github.com/robbyrussell/oh-my-zsh.git "$ZSH"
fi

source $ZSH/oh-my-zsh.sh
