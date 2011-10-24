syntax on

" Visual
  set number
  set ruler
  set guioptions=ce
  set showmatch                 " Briefly jump to a paren once it's balanced
  set linespace=2
  set cursorline
  set background=dark
  colorscheme Tomorrow-Night

" Tabs/Whitespace
  set tabstop=2
  set shiftwidth=2
  set autoindent
  set smarttab
  set expandtab
  set nowrap
  set list
  set listchars=tab:▸\ ,eol:¬,trail:·
  set backspace=indent,eol,start " allow backspacing over everything in insert mode

" Misc
  set switchbuf=useopen         " Don't re-open already opened buffers
  set nostartofline             " Avoid moving cursor to BOL when jumping around
  set virtualedit=all           " Let cursor move past the last char
  set whichwrap=b,s,h,l,<,>,[,]
  let mapleader = ','
  set autoread                  " watch for file changes
  set mouse=a
  set fileformats=unix

" Bells
  set novisualbell  " No blinking
  set noerrorbells  " No noise.
  set vb t_vb= " disable any beeps or flashes on error

" Searching
  set hlsearch
  set incsearch
  set ignorecase
  set smartcase

" Tab completion
  set wildmode=list:longest,list:full
  set wildignore+=*.o,*.obj,.git,*.rbc,*.swp

" Status bar
  set laststatus=2
  set statusline=%<%f\ %h%m%r%{fugitive#statusline()}%=%-14.(%l,%c%V%)\ %P

" Folding
  set foldenable " Turn on folding
  set foldmethod=marker " Fold on the marker
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
  map <C-_> :split<CR>
  map <C-\> :vsplit<CR>

" Emacs-like keys for the command line
  cnoremap <C-A> <Home>
  cnoremap <C-E> <End>
  cnoremap <C-K> <C-U>

" Move around in insert mode
  inoremap <C-h> <left>
  inoremap <C-k> <up>
  inoremap <C-j> <down>
  inoremap <C-l> <right>

" Opens an edit command with the path of the currently edited file filled in Normal mode: <Leader>e
  map <Leader>e :e <C-R>=expand("%:p:h") . "/" <CR>

" Strip trailing whitespace on save
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
  autocmd! BufWritePre * :call <SID>StripTrailingWhitespaces()
