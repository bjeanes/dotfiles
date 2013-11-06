
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

" Strip trailing whitespace on command
nmap <Leader>sw :call <SID>StripTrailingWhitespaces()<CR>

augroup the_rest
  au!

  " Attempted fix for Vim losing mouse support when inside Tmux
  autocmd TermResponse,CursorHold,CursorHoldI * set ttymouse=xterm2

  " Create parent directory if it doesn't exist before writing file
  " (http://stackoverflow.com/questions/4292733/vim-creating-parent-directories-on-save)
  autocmd BufWritePre * if expand("<afile>")!~#'^\w\+:/' && !isdirectory(expand("%:h")) | execute "silent! !mkdir -p ".shellescape(expand('%:h'), 1) | redraw! | endif

  " Source vimrc after saving it
  autocmd BufWritePost .vimrc,vimrc source $MYVIMRC | NERDTreeToggle | NERDTreeToggle

  " Auto save files on window blur
  autocmd FocusLost * :silent! up

  " make and python use real tabs
  autocmd FileType make    set noexpandtab
  autocmd FileType python  set noexpandtab

  " Thorfile, Rakefile and Gemfile are Ruby
  autocmd BufRead,BufNewFile {Gemfile,Rakefile,Thorfile,config.ru}    set ft=ruby

  autocmd BufRead,BufNewFile gitconfig set ft=gitconfig

  " Strip trailing whitespace on save
  autocmd BufWritePre * :call <SID>StripTrailingWhitespaces()
augroup end


