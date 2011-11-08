syntax on

" Visual
  set ruler
  set guioptions=ce
  set showmatch                 " Briefly jump to a paren once it's balanced
  set linespace=2
  set background=dark
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
  nnoremap <silent> <Leader>c :set nolist!<CR>

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
  noremap <silent> <Space> <Esc>:noh<CR><Space>

" Tab completion
  set wildmode=list:longest,list:full
  set wildignore+=*.o,*.obj,.git,*.rbc,*.swp

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

" way better...
  map 0 ^

" Opens an edit command with the path of the currently
" edited file filled in Normal mode: <Leader>e
  map <Leader>e :e <C-R>=expand("%:p:h") . "/" <CR>

"  Always show cursorline, but only in current window.
  set cursorline
  autocmd WinEnter * :setlocal cursorline
  autocmd WinLeave * :setlocal nocursorline

" Always show line numbers, but only in current window (great for smaller screens).
  set number
  autocmd WinEnter * :setlocal number
  autocmd WinLeave * :setlocal nonumber

" automatically resize vertical splits (great for smaller screens).
" TODO: ignore NerdTree
  autocmd WinEnter NERD_tree_* :setlocal winfixwidth
  autocmd WinEnter * :set winfixheight
  autocmd WinEnter * :wincmd ="


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
