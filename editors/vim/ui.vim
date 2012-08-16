syntax on

" Visual
  set ruler
  set guioptions=ce
  set showmatch                 " Briefly jump to a paren once it's balanced
  set linespace=2
  set background=dark
  set laststatus=2
  colorscheme molokai_mac

" Tabs/Whitespace
  set tabstop=2
  set shiftwidth=2
  set autoindent
  set smarttab
  set expandtab
  set nowrap
  set list
  set backspace=indent,eol,start " allow backspacing over everything in insert mode

  " Toggle show tabs and trailing spaces (,c)
  set listchars=tab:▸\ ,trail:·,eol:¬,nbsp:_
  set fillchars=vert:\ ,fold:-
  nnoremap <Leader>c :set nolist!<CR>

" Misc
  set switchbuf=useopen         " Don't re-open already opened buffers
  set nostartofline             " Avoid moving cursor to BOL when jumping around
  set virtualedit=all           " Let cursor move past the last char
  set whichwrap=b,s,h,l,<,>,[,]
  let mapleader = ','
  set autoread                  " watch for file changes
  set mouse=a
  set ttymouse=xterm2           " Needed to get mouse working when in Tmux/screen
  set fileformats=unix
  set history=1000
  set hidden
  set title                     " Show title in Terminal
  set shortmess=atI

" Bells
  set novisualbell  " No blinking
  set noerrorbells  " No noise.
  set vb t_vb= " disable any beeps or flashes on error

" Searching
  set hlsearch
  set incsearch
  set ignorecase
  set smartcase

  " Remove highlighting when entering insert (not working... )
  autocmd InsertEnter * nohlsearch

  " center result
  nnoremap n nzz
  nnoremap N Nzz
  nnoremap * *zz
  nnoremap # #zz
  nnoremap g* g*zz
  nnoremap g# g#zz

" Work around bug that leaves cursor in middle of line
  nnoremap dd ddI<Esc>

" Tab completion
  set wildmode=list:longest,list:full
  set wildignore+=*.o,*.obj,.git,*.rbc,*.swp

" Folding
  set foldenable " Turn on folding
  set foldmethod=syntax " Fold on the marker
  set foldlevel=100 " Don't autofold anything (but I can still fold manually)
  set foldopen=block,hor,mark,percent,quickfix,tag " what movements open folds

" Directories for swp files
  " persistent undos
    set undofile
    set undodir=~/.vim/dirs/undos

  set backupdir=~/.vim/dirs/backups
  set directory=~/.vim/dirs/swaps

" Nicer text navigation
  nmap j gj
  nmap k gk

" Reselect visual block after adjusting indentation
  vnoremap < <gv
  vnoremap > >gv

" Nicer splitting
  set splitbelow
  set splitright
  map <C-_> :new<CR>
  map <C-\> :vnew<CR>

" Emacs-like keys for the command line
  cnoremap <C-A> <Home>
  cnoremap <C-E> <End>
  cnoremap <C-K> <C-U>

" Move around in insert mode
  inoremap <C-h> <left>
  inoremap <C-k> <up>
  inoremap <C-j> <down>
  inoremap <C-l> <right>

" way better...
  map 0 ^

  nmap <Leader>] :tabnext<CR>
  nmap <Leader>[ :tabprev<CR>

" Opens an edit command with the path of the currently
" edited file filled in Normal mode: <Leader>e
  map <Leader>e :e <C-R>=expand("%:p:h") . "/" <CR>

"  Always show cursorline, but only in current window.
  set scrolloff=3
  set scrolljump=10
  set cursorline
  autocmd WinEnter * :setlocal cursorline
  autocmd WinLeave * :setlocal nocursorline

  set number

  " For when other people use my setup
  nmap \ <Leader>

  " Easier
  nnoremap ; :

  " I keep deleting words when I want to switch windows
  imap <C-w> <Esc><C-w>

  " OS X clipboard when yanking/pasting
  set clipboard=unnamed

  " May only work in iTerm2 and may have other bad effects,
  " but this shows a block in normal mode, and vertical bar
  " in insert mode.
  if exists('$TMUX')
    " https://github.com/sjl/vitality.vim/issues/8#issuecomment-7664649
    let &t_SI = "\<Esc>[3 q"
    let &t_EI = "\<Esc>[0 q"
  else
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
  endif

  runtime macros/matchit.vim
