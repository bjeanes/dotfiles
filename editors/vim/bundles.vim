augroup bundles
  autocmd!

  if has('vim_starting')
    set nocompatible
    set runtimepath+=~/.vim/bundle/neobundle.vim/
  endif

  call neobundle#rc(expand('~/.vim/bundle/'))

  " Let NeoNeoBundle manage NeoBundle
  NeoBundleFetch 'Shougo/neobundle.vim'

  NeoBundle 'Shougo/vimproc', {
  \ 'build' : {
  \     'mac' : 'make -f make_mac.mak',
  \     'unix' : 'make -f make_unix.mak',
  \    },
  \ }

  " Languages/Syntaxes/Frameworks {{{
    " Ruby {{{
      NeoBundleLazy 'vim-ruby/vim-ruby'
      NeoBundleLazy 'tpope/vim-endwise'
      NeoBundleLazy 'tpope/vim-rake'
      NeoBundleLazy 'thisivan/vim-ruby-matchit'
      NeoBundleLazy 'nelstrom/vim-textobj-rubyblock', { 'depends' : 'kana/vim-textobj-user' }
      autocmd FileType ruby NeoBundleSource
      \ vim-ruby
      \ vim-rake
      \ vim-endwise
      \ vim-haml
      \ vim-ruby-matchit
      \ vim-textobj-rubyblock
    " }}}

    " Clojure {{{
      NeoBundleLazy 'paredit.vim'
      NeoBundleLazy 'VimClojure'
      let g:vimclojure#ParenRainbow = 1
      let vimclojure#FuzzyIndent = 1
      autocmd FileType clojure,clojurescript set lispwords-='->'
      autocmd FileType clojure,clojurescript set lispwords-='->>'
      autocmd FileType clojure,clojurescript NeoBundleSource paredit.vim VimClojure
    " }}}

    " Markdown/Textile/etc {{{
      NeoBundleLazy 'tpope/vim-markdown'
      NeoBundleLazy 'matthias-guenther/hammer.vim'
      autocmd FileType markdown NeoBundleSource vim-markdown hammer.vim
    " }}}

    " HTML/CSS/Javascript {{{
      NeoBundleLazy 'tpope/vim-haml',           { 'autoload' : { 'filetypes' : 'haml' } }
      NeoBundleLazy 'kchmck/vim-coffee-script', { 'autoload' : { 'filetypes' : 'coffee' } }
      NeoBundleLazy 'pangloss/vim-javascript',  { 'autoload' : { 'filetypes' : 'javascript' } }
      NeoBundleLazy 'css3',                     { 'autoload' : { 'filetypes' : 'css' } }
      NeoBundleLazy 'othree/html5-syntax.vim',  { 'autoload' : { 'filetypes' : 'html' } }
      NeoBundleLazy 'slim-template/vim-slim',   { 'autoload' : { 'filetypes' : 'slim' } }
    " }}}

  " }}}

  " Git {{{
    NeoBundle 'tpope/vim-fugitive', { 'augroup': 'fugitive' }
    NeoBundle 'tpope/vim-git'
    NeoBundle 'tjennings/git-grep-vim'
  " }}}

  " Text objects {{{
    NeoBundle 'michaeljsmith/vim-indent-object'
    NeoBundle 'argtextobj.vim'
  " }}}

  " Utility {{{

    NeoBundle 'tpope/vim-surround'

    NeoBundle 'Raimondi/delimitMate'
    autocmd FileType clojure let delimitMate_quotes = "\""

    NeoBundle 'AutoComplPop'
    let g:acp_enableAtStartup        = 0
    let g:acp_completeoptPreview     = 1
    let g:acp_behaviorKeywordLength  = 3
    let g:acp_behaviorKeywordIgnores = [
      \ 'the', 'def', 'end',
      \ 'else', 'elsif', 'elif', 'endif', 'then',
      \ 'case', 'done', 'do'
      \ ]

    NeoBundle 'Lokaltog/vim-easymotion'
    let g:EasyMotion_keys = "arstdhneio" " Colemak home row

    NeoBundle 'Lokaltog/vim-powerline'

    NeoBundle 'Gundo'
    nnoremap <Leader>u :GundoToggle<CR>

    NeoBundle 'kien/rainbow_parentheses.vim'
    autocmd VimEnter *.{rb,coffee} RainbowParenthesesToggle
    autocmd Syntax   *.{rb,coffee} RainbowParenthesesLoadRound
    autocmd Syntax   *.{rb,coffee} RainbowParenthesesLoadSquare
    autocmd Syntax   *.{rb,coffee} RainbowParenthesesLoadBraces

    NeoBundle 'Tabular'
    autocmd VimEnter * AddTabularPattern! first_eq     /\%(=.*\)\@<!=[>=]\@!/l1c1l0
    autocmd VimEnter * AddTabularPattern! first_rocket /\%(=>.*\)\@<!=>/l1c1l0
    autocmd VimEnter * AddTabularPattern! first_key    /\v%(%(\h\w*|"[^"]+"):.*)@<!%(\h\w*|"[^"]+")\zs:/l0l1

    " mark, select indent level, tabularize, go to mark
    nmap <silent> <Leader>a= mT:Tabularize first_eq<CR>`T
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

    NeoBundle 'scrooloose/nerdcommenter'
    let NERDCreateDefaultMappings = 0
    let NERDSpaceDelims = 1 " space between comment and code
    map  // <plug>NERDCommenterToggle
    vmap // <plug>NERDCommenterToggle gv
    map  <Leader>/ //
    vmap <Leader>/ //

    NeoBundle 'ZoomWin'
    map <Leader>z :ZoomWin<CR>
    imap <Leader>z <Esc>:ZoomWin<CR>a

    NeoBundle 'scrooloose/nerdtree', { 'augroup' : 'NERDTreeHijackNetrw' }
    let g:NERDTreeIgnore      = ['\.rbc$', '\~$', '.DS_Store$']
    let g:NERDTreeChDirMode   = 2
    let g:NERDTreeMouseMode   = 3
    let g:NERDTreeQuitOnOpen  = 1
    let g:NERDTreeMinimalUI   = 1
    let g:NERDTreeDirArrows   = 1
    let g:NERDTreeHijackNetrw = 0
    map <Space>n :NERDTreeToggle<CR>
    map <Leader>n :NERDTreeToggle<CR>
    map <Leader>N :NERDTreeFind<CR>

    NeoBundle 'wincent/Command-T', {
    \   'build' : {
    \     'mac'  : '/usr/bin/ruby ruby/command-t/extconf.rb && make',
    \     'unix' : 'ruby ruby/command-t/extconf.rb && make'
    \   }
    \ }
    let g:CommandTMaxFiles  = 20000
    let g:CommandTMaxHeight = 10
    nnoremap <silent> <Leader>t :CommandT<CR>
    nnoremap <silent> <Leader>b :CommandTBuffer<CR>
    nnoremap <Leader>f :CommandTFlush<CR>

    NeoBundle 'Indent-Guides'
    let g:indent_guides_auto_colors = 0
    let g:indent_guides_enable_on_vim_startup = 1
    autocmd VimEnter * IndentGuidesEnable
    autocmd FileType clojure IndentGuidesDisable

    NeoBundle 'Syntastic'
    let g:syntastic_enable_signs       = 1
    let g:syntastic_auto_loc_list      = 0
    let g:syntastic_disabled_filetypes = ['cucumber']
  " }}}

  " Other {{{
    NeoBundle 'thisivan/vim-matchit'
  " }}}

  filetype plugin indent on

  NeoBundleCheck
augroup END
