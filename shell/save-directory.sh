if [ ! -f ~/.dirs ]; then
	touch ~/.dirs
fi

alias show='cat ~/.dirs'
save (){
	command sed "/!$/d" ~/.dirs > ~/.dirs1
	mv ~/.dirs1 ~/.dirs; echo "$@"=\"`pwd`\" >> ~/.dirs
	source ~/.dirs
}
source ~/.dirs  # Initialization for the above 'save' facility: source the .dirs file
