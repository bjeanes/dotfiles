" RSpec

  " Syntax highlighting
    if expand('%') =~# '_spec\.rb$'
      syn keyword rubyRspec describe context it specify it_should_behave_like before after setup subject let shared_context shared_examples_for
    endif

    hi def link rubyRspec Function

  " Focus folding on spec"
    nmap <silent> <Leader>rf mr:set foldmethod=syntax<CR>zMzv?\v^\s*(it\|example)<CR>zz:noh<CR>`r:delmarks r<CR>
