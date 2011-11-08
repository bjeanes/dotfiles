if !has('conceal')
  finish
endif

syntax keyword rubyControl not conceal cchar=¬
syntax keyword rubyKeyword lambda conceal cchar=λ
syntax match rubyGreaterThanOrEqual ">=" conceal cchar=≥
syntax match rubyLessThanOrEqual "<=" conceal cchar=≤

set conceallevel=2

