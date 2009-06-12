function save --description 'Save current directory with name for quick access'
    ln -s "$PWD" "$HOME/.l/$argv"
end
