syntax on

" Visual
  set ruler
  set guioptions=ce
  set showmatch                  " Briefly jump to a paren once it's balanced
  set linespace=2
  set background=dark
  set laststatus=2
  colorscheme molokai_mac

  set rtp+=~/.config/vendor/powerline/powerline/bindings/vim


" Tabs/Whitespace
  set tabstop=2                  " a Tab take up 2 spaces
  set shiftwidth=2               " (un)indent 2 spaces at at ime
  set autoindent                 " preserve previous indent level when inserting new line
  set smarttab                   " insert/delete a tab's work of spaces at a time
  set expandtab                  " insert actual spaces, not tabs
  set nowrap                     " don't wrap long lines
  set backspace=indent,eol,start " allow backspacing over everything in insert mode

  " Toggle show tabs and trailing spaces (,c)
  set list
  set listchars=tab:▸\ ,trail:·,eol:¬,nbsp:_
  set fillchars=vert:\ ,fold:-
  nnoremap <Leader>c :set list!<CR>

" Misc
  set switchbuf=useopen         " Don't re-open already opened buffers
  set nostartofline             " Avoid moving cursor to BOL when jumping around
  set virtualedit=all           " Let cursor move past the last char
  set whichwrap=b,s,h,l,<,>,[,]
  let mapleader = ','           " comma as leader key
  " but be nice to people who are used to backslash:
  nmap \ <Leader>
  set autoread                  " watch for file changes
  set mouse=a                   " mouse can be handy sometimes
  set ttymouse=xterm2           " Needed to get mouse working when in Tmux/screen
  set fileformats=unix
  set history=1000
  set nohidden                  " unload a buffer when abandoned, please
  set title                     " Show title in Terminal
  set shortmess=atI             " abbreviate messages

" Bells
  set novisualbell              " No blinking
  set noerrorbells              " No noise.
  set vb t_vb=                  " disable any beeps or flashes on error

" Searching
  set hlsearch                  " highlight search matches and keep them highlighted
  set incsearch                 " start matching search before hitting enter
  set ignorecase                " case-insensitive searching by default
  set smartcase                 " but if searching with multiple cases, treat it as case-sensitive

  " center current search result in middle of screen
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

" Directories for swp files

" Navigate cursor up/down by lines on screen, not lines in file
  nmap j gj
  nmap k gk

" Reselect visual block after adjusting indentation
  vnoremap < <gv
  vnoremap > >gv

" Nicer splitting
  set splitbelow
  set splitright

" Emacs-like keys for the command line
  cnoremap <C-A> <Home>
  cnoremap <C-E> <End>
  cnoremap <C-K> <C-U>

"  Always show cursorline, but only in current window.
  set scrolloff=3
  set scrolljump=10
  set cursorline
  autocmd WinEnter * :setlocal cursorline
  autocmd WinLeave * :setlocal nocursorline

set number " line numbers

" I keep deleting words when I want to switch windows
imap <C-w> <Esc><C-w>

set clipboard=unnamed " OS X clipboard when yanking/pasting

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
