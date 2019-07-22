if expand('%') =~# '_spec\.rb$'
  syn keyword rubyRspec describe context it specify it_should_behave_like before after setup subject let shared_context shared_examples_for shared_examples
endif

hi def link rubyRspec Function

nmap <silent> <Leader>rf mr:set foldmethod=syntax<CR>zMzv?\v^\s*(it\|example)<CR>zz:noh<CR>`r:delmarks r<CR>

let s:bcs = b:current_syntax
unlet b:current_syntax
syntax include @SQL syntax/sql.vim
let b:current_syntax = s:bcs

syntax region hereDocDashSQL matchgroup=Statement start=+<<[-~.]\?\z(SQL\%(DOC\)\?\)+ end=+^\s*\z1+ contains=@SQL

