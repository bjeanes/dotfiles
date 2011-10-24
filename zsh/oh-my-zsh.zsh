export ZSH=$DOT_FILES/zsh/lib/oh-my-zsh
export ZSH_THEME="risto"
plugins=(rails git ruby osx brew)

if [ -d "$ZSH" ]; then
  source $ZSH/oh-my-zsh.sh
else
  echo "Cloning Oh My Zsh..."
  /usr/bin/env git clone git://github.com/robbyrussell/oh-my-zsh.git "$ZSH"
  source $ZSH/oh-my-zsh.sh
fi
