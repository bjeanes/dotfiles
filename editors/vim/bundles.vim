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

  if has("mac") || has("macunix")
    NeoBundle 'rizzatti/funcoo.vim'
    NeoBundle 'rizzatti/dash.vim'

    nmap <silent> K <Plug>DashSearch
  endif

  NeoBundle 'tpope/vim-sleuth' " auto-config indent and tabs etc based on other files

  NeoBundle 'tpope/vim-endwise' " Auto-add 'end' etc appropriately in various languages
  NeoBundle 'kana/vim-smartinput'
  NeoBundleLazy 'tpope/vim-vinegar', { 'autoload' : { 'filetypes' : ['netrw'] } }

  " Languages/Syntaxes/Frameworks {{{
    NeoBundleLazy 'wting/rust.vim', { 'autoload' : { 'filetypes' : ['rust'] } }
    au BufNewFile,BufRead *.rs set filetype=rust

    NeoBundleLazy 'jnwhiteh/vim-golang', { 'autoload' : { 'filetypes' : ['go'] } }
    au BufNewFile,BufRead *.go set filetype=go
    au FileType go autocmd BufWritePre <buffer> Fmt
    au FileType go set noexpandtab

    " Ruby {{{
      NeoBundleLazy 'vim-ruby/vim-ruby'
      NeoBundleLazy 'tpope/vim-rails'
      NeoBundleLazy 'tpope/vim-rake'
      NeoBundleLazy 'tpope/vim-bundler'
      NeoBundleLazy 'thisivan/vim-ruby-matchit'
      NeoBundleLazy 'nelstrom/vim-textobj-rubyblock', { 'depends' : ['kana/vim-textobj-user', 'thisivan/vim-matchit'] }
      autocmd FileType ruby NeoBundleSource
      \ vim-ruby
      \ vim-rails  " <- how to maket his only load in rails projects?
      \ vim-bundler
      \ vim-rake
      \ vim-haml
      \ vim-ruby-matchit
      \ vim-textobj-rubyblock
    " }}}

    " Clojure(script) {{{
      NeoBundleLazy 'guns/vim-clojure-static'
      NeoBundleLazy 'guns/vim-sexp', { 'depends' : ['tpope/vim-repeat'] }
      NeoBundleLazy 'tpope/vim-sexp-mappings-for-regular-people', { 'depends' : ['guns/vim-sexp'] }
      NeoBundleLazy 'tpope/vim-dispatch'
      NeoBundleLazy 'tpope/vim-leiningen', { 'depends' : ['tpope/vim-dispatch'] }
      NeoBundleLazy 'tpope/vim-fireplace', { 'depends' : ['tpope/vim-leiningen']}

      autocmd FileType clojure,clojurescript NeoBundleSource
            \ vim-clojure-static
            \ vim-sexp-mappings-for-regular-people
            \ vim-fireplace

      autocmd FileType clojure,clojurescript set lispwords-='->'
      autocmd FileType clojure,clojurescript set lispwords-='->>'
    " }}}

    NeoBundleLazy 'tpope/vim-markdown', { 'autoload' : { 'filetypes' : ['markdown'] } }

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

    NeoBundle 'tpope/vim-surround', { 'depends' : 'tpope/vim-repeat' }

    NeoBundleLazy 'AutoComplPop', { 'autoload' : { 'insert' : 1 } }
    let g:acp_enableAtStartup        = 0
    let g:acp_completeoptPreview     = 1
    let g:acp_behaviorKeywordLength  = 3
    let g:acp_behaviorKeywordIgnores = [
      \ 'the', 'def', 'end',
      \ 'else', 'elsif', 'elif', 'endif', 'then',
      \ 'case', 'done', 'do'
      \ ]

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

    NeoBundle 'tpope/vim-commentary'
    autocmd FileType clojure,clojurescript set commentstring=;\ %s
    nmap // <Plug>CommentaryLine
    vmap // <Plug>Commentary

    NeoBundle 'kien/ctrlp.vim'

    NeoBundle 'Syntastic'
    let g:syntastic_enable_signs       = 1
    let g:syntastic_auto_loc_list      = 0
  " }}}

  filetype plugin indent on

  NeoBundleCheck
augroup END
