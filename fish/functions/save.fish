function save --description 'Save current directory with name for quick access'
    echo "ln -s \"$PWD\" \"~/.l/$argv\" ./"
    ln -s "$PWD" "~/.l/$argv"

end
