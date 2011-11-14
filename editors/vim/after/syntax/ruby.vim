if !has('conceal')
  finish
endif

syntax keyword rubyControl not conceal cchar=¬
syntax keyword rubyKeyword lambda conceal cchar=λ
syntax match rubyGreaterThanOrEqual ">=" conceal cchar=≥
syntax match rubyLessThanOrEqual "<=" conceal cchar=≤
syntax match rubyHashRocket "=>" conceal cchar=→

hi link rubyHashRocket level16none

set conceallevel=2

