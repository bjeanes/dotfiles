filetype off

set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" Let Vundle manage Vundle
  Bundle 'gmarik/vundle'

" Experimenting
  Bundle 'robgleeson/hammer.vim'
  let g:HammerQuiet = 1

" Languages/Syntaxes/Frameworks {{{
  " Ruby {{{
  Bundle 'vim-ruby/vim-ruby'
  Bundle 'tpope/vim-endwise'
  Bundle 'tpope/vim-rake'
  Bundle 'tpope/vim-rails'
  Bundle 'tpope/vim-haml'
  " }}}

  " Markdown/Textile/etc {{{
  Bundle 'tpope/vim-markdown'
  " }}}

  " Other {{{
  Bundle 'tpope/vim-cucumber'
  Bundle 'skammer/vim-css-color'
  Bundle 'kchmck/vim-coffee-script'
  " }}}
" }}}

" Git {{{
  Bundle 'tpope/vim-fugitive'
  Bundle 'tpope/vim-git'
" }}}

" Utility {{{
  Bundle 'tpope/vim-bundler'
  Bundle 'tjennings/git-grep-vim'

  Bundle 'scrooloose/nerdcommenter'
  let NERDSpaceDelims = 1 " space between comment and code

  Bundle 'ZoomWin'
  map <Leader>z :ZoomWin<CR>
  imap <Leader>z <Esc>:ZoomWin<CR>

  Bundle 'vimwiki'
  let g:vimwiki_hl_cb_checked = 1
  let g:vimwiki_menu          = 'Plugin.Vimwiki'
  let g:vimwiki_badsyms       = ' '
  let g:vimwiki_use_mouse     = 1
  let g:vimwiki_dir_link      = 'index'
  let g:vimwiki_list          = [
    \  {
    \     'path': '~/Dropbox/Wiki/Text',
    \     'path_html': '~/Dropbox/Wiki/HTML',
    \     'nested_syntaxes': {
    \       'ruby': 'ruby'
    \     }
    \  }
    \]

  Bundle 'scrooloose/nerdtree'
  let NERDTreeIgnore     = ['\.rbc$', '\~$']
  let NERDTreeChDirMode  = 2
  let NERDTreeMouseMode  = 3
  let NERDTreeQuitOnOpen = 1
  let NERDTreeMinimalUI  = 1
  let NERDTreeDirArrows  = 1
  map <Leader>n :NERDTreeToggle<CR>

  Bundle 'Command-T'
  let g:CommandTMaxFiles  = 20000
  let g:CommandTMaxHeight = 10
  set wildignore+=Transmission*Remote*GUI

  Bundle 'Indent-Guides'
  let g:indent_guides_color_change_percent = 7
  autocmd! VimEnter * IndentGuidesEnable

  Bundle 'Syntastic'
  let g:syntastic_enable_signs  = 1
  let g:syntastic_auto_loc_list = 0
" }}}

autocmd! BufWritePost bundles.vim source ~/.vim/bundles.vim
filetype plugin indent on

