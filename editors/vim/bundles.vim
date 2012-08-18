augroup bundles
  autocmd!

  filetype off

  set rtp+=~/.vim/bundle/vundle/
  call vundle#rc()

  " Let Vundle manage Vundle
    Bundle 'gmarik/vundle'

  " Languages/Syntaxes/Frameworks {{{
    " Ruby {{{
      Bundle 'vim-ruby/vim-ruby'
      Bundle 'tpope/vim-endwise'
      Bundle 'tpope/vim-rake'
      Bundle 'tpope/vim-haml'
      Bundle 'ecomba/vim-ruby-refactoring'
      Bundle 'thisivan/vim-ruby-matchit'

      Bundle 'tpope/vim-cucumber'
    " }}}

    " Clojure {{{
      Bundle 'paredit.vim'
      Bundle 'VimClojure'
      let g:vimclojure#ParenRainbow = 1
      let vimclojure#FuzzyIndent = 1
      autocmd FileType clojure set lispwords-='->'
      autocmd FileType clojure set lispwords-='->>'
    " }}}

    " Markdown/Textile/etc {{{
      Bundle 'tpope/vim-markdown'
      Bundle 'matthias-guenther/hammer.vim'
    " }}}

    " HTML/CSS/Javascript {{{
      Bundle 'kchmck/vim-coffee-script'
      Bundle 'pangloss/vim-javascript'
      Bundle 'css3'
      Bundle 'othree/html5-syntax.vim'
    " }}}

  " }}}

  " Git {{{
    Bundle 'tpope/vim-fugitive'
    Bundle 'tpope/vim-git'
    Bundle 'tjennings/git-grep-vim'
  " }}}

  " Text objects {{{
    Bundle 'kana/vim-textobj-user'
    Bundle 'nelstrom/vim-textobj-rubyblock'
    Bundle 'michaeljsmith/vim-indent-object'
    Bundle 'argtextobj.vim'
  " }}}

  " Utility {{{

    Bundle 'tpope/vim-surround'

    Bundle 'Raimondi/delimitMate'
    autocmd FileType clojure let delimitMate_quotes = "\""

    Bundle 'AutoComplPop'
    let g:acp_enableAtStartup        = 0
    let g:acp_completeoptPreview     = 1
    let g:acp_behaviorKeywordLength  = 3
    let g:acp_behaviorKeywordIgnores = [
      \ 'the', 'def', 'end',
      \ 'else', 'elsif', 'elif', 'endif', 'then',
      \ 'case', 'done', 'do'
      \ ]

    Bundle 'Lokaltog/vim-easymotion'
    let g:EasyMotion_keys = "arstdhneio" " Colemak home row

    Bundle 'Lokaltog/vim-powerline'

    Bundle 'Gundo'
    nnoremap <Leader>u :GundoToggle<CR>

    Bundle 'kien/rainbow_parentheses.vim'
    autocmd VimEnter *.{rb,coffee} RainbowParenthesesToggle
    autocmd Syntax   *.{rb,coffee} RainbowParenthesesLoadRound
    autocmd Syntax   *.{rb,coffee} RainbowParenthesesLoadSquare
    autocmd Syntax   *.{rb,coffee} RainbowParenthesesLoadBraces

    Bundle 'Tabular'
    autocmd VimEnter * AddTabularPattern! first_eq     /\%(=.*\)\@<!=[>=]\@!/l1c1l0
    autocmd VimEnter * AddTabularPattern! first_rocket /\%(=>.*\)\@<!=>/l1c1l0
    autocmd VimEnter * AddTabularPattern! first_key    /\v%(%(\h\w*|"[^"]+"):.*)@<!%(\h\w*|"[^"]+")\zs:/l0l1

    " mark, select indent level, tabularize, go to mark
    nmap <silent> <Leader>a = mT:Tabularize first_eq<CR>`T
    nmap <silent> <Leader>a> mT:Tabularize first_rocket<CR>`T
    nmap <silent> <Leader>a: mT:Tabularize first_key<CR>`T

    vmap <silent> <Leader>a= :Tabularize first_eq<CR>gv
    vmap <silent> <Leader>a> :Tabularize first_rocket<CR>gv
    vmap <silent> <Leader>a: :Tabularize first_key<CR>gv

    " Auto-align
    "" Cucumber
    inoremap <silent> <Bar> <Bar><Esc>:call <SID>align()<CR>a
    function! s:align()
      let p = '^\s*|\s.*\s|\s*$'
      if exists(':Tabularize') && getline('.') =~# '^\s*|' && (getline(line('.')-1) =~# p || getline(line('.')+1) =~# p)
        let column = strlen(substitute(getline('.')[0:col('.')],'[^|]','','g'))
        let position = strlen(matchstr(getline('.')[0:col('.')],'.*|\s*\zs.*'))
        Tabularize/|/l1
        normal! 0
        call search(repeat('[^|]*|',column).'\s\{-\}'.repeat('.',position),'ce',line('.'))
      endif
    endfunction

    Bundle 'scrooloose/nerdcommenter'
    let NERDCreateDefaultMappings = 0
    let NERDSpaceDelims = 1 " space between comment and code
    map  // <plug>NERDCommenterToggle
    vmap // <plug>NERDCommenterToggle gv
    map  <Leader>/ //
    vmap <Leader>/ //

    Bundle 'ZoomWin'
    map <Leader>z :ZoomWin<CR>
    imap <Leader>z <Esc>:ZoomWin<CR>a

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
    let g:NERDTreeIgnore      = ['\.rbc$', '\~$', '.DS_Store$']
    let g:NERDTreeChDirMode   = 2
    let g:NERDTreeMouseMode   = 3
    let g:NERDTreeQuitOnOpen  = 1
    let g:NERDTreeMinimalUI   = 1
    let g:NERDTreeDirArrows   = 1
    let g:NERDTreeHijackNetrw = 0
    map <Space>n :NERDTreeToggle<CR>
    map <Leader>N :NERDTreeFind<CR>

    Bundle 'Command-T'
    let g:CommandTMaxFiles  = 20000
    let g:CommandTMaxHeight = 10
    nnoremap <silent> <Leader>t :CommandT<CR>
    nnoremap <silent> <Leader>b :CommandTBuffer<CR>
    nnoremap <Leader>f :CommandTFlush<CR>

    Bundle 'Indent-Guides'
    let g:indent_guides_auto_colors = 0
    let g:indent_guides_enable_on_vim_startup = 1
    autocmd VimEnter * IndentGuidesEnable
    autocmd FileType clojure IndentGuidesDisable

    Bundle 'Syntastic'
    let g:syntastic_enable_signs       = 1
    let g:syntastic_auto_loc_list      = 0
    let g:syntastic_disabled_filetypes = ['cucumber']
  " }}}

  " Other {{{
    Bundle 'AnsiEsc.vim'
    Bundle 'thisivan/vim-matchit'

    Bundle 'aklt/plantuml-syntax'
    au BufNewFile,BufRead *.uml set filetype=plantuml
  " }}}

  autocmd BufWritePost bundles.vim source ~/.vim/bundles.vim
  filetype plugin indent on
augroup END
