" Source vimrc after saving it
autocmd! BufWritePost .vimrc,vimrc source $MYVIMRC | NERDTreeToggle | NERDTreeToggle

" Auto save files on window blur
autocmd! FocusLost * :silent! up

" make and python use real tabs
au! FileType make    set noexpandtab
au! FileType python  set noexpandtab

au! FileType scss    syntax cluster sassCssAttributes add=@cssColors

" Thorfile, Rakefile and Gemfile are Ruby
au! BufRead,BufNewFile {Gemfile,Rakefile,Thorfile,config.ru}    set ft=ruby

au! BufRead,BufNewFile gitconfig set ft=gitconfig

function! <SID>StripTrailingWhitespaces()
  " Preparation: save last search, and cursor position.
  let _s=@/
  let l = line(".")
  let c = col(".")
  " Do the business:
  %s/\s\+$//e
  " Clean up: restore previous search history, and cursor position
  let @/=_s
  call cursor(l, c)
endfunction

" Strip trailing whitespace on save
autocmd! BufWritePre * :call <SID>StripTrailingWhitespaces()

" Strip trailing whitespace on command
nmap <Leader>sw :call <SID>StripTrailingWhitespaces()<CR>


