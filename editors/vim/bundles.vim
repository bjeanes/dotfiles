if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
      \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

Plug 'w0ng/vim-hybrid' " color scheme

Plug 'tpope/vim-sensible' " Sensible defaults, duh

Plug 'tpope/vim-commentary'
Plug 'tpope/vim-dispatch'
Plug 'tpope/vim-endwise'  " Auto-add 'end' etc appropriately in various languages
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-git'
Plug 'tpope/vim-repeat'
"Plug 'tpope/vim-sleuth'   " auto-config indent and tabs etc based on other files
Plug 'tpope/vim-surround' " quoting/parenthesizing made simple
Plug 'tpope/vim-vinegar'  " Nicer netrw
Plug 'terryma/vim-expand-region'
if has('signs')
  Plug 'airblade/vim-gitgutter'
endif
Plug 'kana/vim-smartinput' " smart pairwise characters
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/vim-peekaboo'
Plug 'junegunn/vim-easy-align', { 'on': ['<Plug>(EasyAlign)', 'EasyAlign'] }
vmap <Enter>   <Plug>(EasyAlign)
nmap <Leader>a <Plug>(EasyAlign)

Plug 'thisivan/vim-matchit'  " Extended % matching for HTML, LaTeX, and many other languages
Plug 'kana/vim-textobj-user' " Create new text objects
Plug 'michaeljsmith/vim-indent-object'
Plug 'argtextobj.vim'

Plug 'neoclide/coc.nvim', {'tag': '*', 'do': { -> coc#util#install()}}


"let g:crystal_auto_format = 1
Plug 'rhysd/vim-crystal' " polyglot doesn't include plugin dir, where much of plugin is set
let g:polyglot_disabled = ['crystal']
Plug 'sheerun/vim-polyglot'

" I pretty much only work with Postgres SQL, so assume *.sql files belong to
" that syntax:
let g:sql_type_default = 'pgsql'

Plug 'tpope/vim-bundler'
Plug 'tpope/vim-rails'
Plug 'tpope/vim-rake'
Plug 'thisivan/vim-ruby-matchit'
Plug 'nelstrom/vim-textobj-rubyblock', { 'for': 'ruby' }

Plug 'ap/vim-css-color'

" Plug 'Chiel92/vim-autoformat'

Plug 'janko-m/vim-test'
let test#strategy = "neovim"  " Run test using vim-dispatch

Plug 'w0rp/ale'
let g:ale_fix_on_save = 1
let g:ale_completion_enabled = 1
let g:ale_fixers = {
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'javascript': ['eslint'],
\   'ruby': ['rubocop'],
\}

Plug 'vim-airline/vim-airline'
let g:airline_powerline_fonts = 1

call plug#end()

"     " Clojure(script) {{{
"       NeoBundleLazy 'guns/vim-sexp', { 'depends' : ['tpope/vim-repeat'] }
"       NeoBundleLazy 'tpope/vim-sexp-mappings-for-regular-people', { 'depends' : ['guns/vim-sexp'] }
"       NeoBundleLazy 'tpope/vim-dispatch'
"       NeoBundleLazy 'tpope/vim-leiningen', { 'depends' : ['tpope/vim-dispatch'] }
"       NeoBundleLazy 'tpope/vim-fireplace', { 'depends' : ['tpope/vim-leiningen']}
"
"       autocmd FileType clojure,clojurescript NeoBundleSource
"             \ vim-clojure-static
"             \ vim-sexp-mappings-for-regular-people
"             \ vim-fireplace
"
"       autocmd FileType clojure,clojurescript set lispwords-='->'
"       autocmd FileType clojure,clojurescript set lispwords-='->>'
"
