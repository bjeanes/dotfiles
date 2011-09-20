" Source vimrc after saving it
autocmd! BufWritePost .vimrc,vimrc source $MYVIMRC | NERDTreeToggle | NERDTreeToggle

" Auto save files on window blur
autocmd! FocusLost * :up

" make and python use real tabs
au! FileType make    set noexpandtab
au! FileType python  set noexpandtab

au! FileType scss    syntax cluster sassCssAttributes add=@cssColors

" Thorfile, Rakefile and Gemfile are Ruby
au! BufRead,BufNewFile {Gemfile,Rakefile,Thorfile,config.ru}    set ft=ruby

au! BufRead,BufNewFile gitconfig set ft=gitconfig
