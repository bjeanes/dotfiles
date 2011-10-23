" Vim color file
" Converted from Textmate theme Tubster using Coloration v0.3.2 (http://github.com/sickill/coloration)

set background=dark
highlight clear

if exists("syntax_on")
  syntax reset
endif

let g:colors_name = "Tubster"

hi Cursor ctermfg=NONE ctermbg=15 cterm=NONE guifg=NONE guibg=#ffffff gui=NONE
hi Visual ctermfg=NONE ctermbg=59 cterm=NONE guifg=NONE guibg=#535c72 gui=NONE
hi CursorLine ctermfg=NONE ctermbg=59 cterm=NONE guifg=NONE guibg=#373636 gui=NONE
hi CursorColumn ctermfg=NONE ctermbg=59 cterm=NONE guifg=NONE guibg=#373636 gui=NONE
hi ColorColumn ctermfg=NONE ctermbg=59 cterm=NONE guifg=NONE guibg=#373636 gui=NONE
hi LineNr ctermfg=244 ctermbg=59 cterm=NONE guifg=#858280 guibg=#373636 gui=NONE
hi VertSplit ctermfg=240 ctermbg=240 cterm=NONE guifg=#5c5a59 guibg=#5c5a59 gui=NONE
hi MatchParen ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi StatusLine ctermfg=188 ctermbg=240 cterm=bold guifg=#e6e1dc guibg=#5c5a59 gui=bold
hi StatusLineNC ctermfg=188 ctermbg=240 cterm=NONE guifg=#e6e1dc guibg=#5c5a59 gui=NONE
hi Pmenu ctermfg=15 ctermbg=NONE cterm=NONE guifg=#ffffff guibg=NONE gui=NONE
hi PmenuSel ctermfg=NONE ctermbg=59 cterm=NONE guifg=NONE guibg=#535c72 gui=NONE
hi IncSearch ctermfg=NONE ctermbg=58 cterm=NONE guifg=NONE guibg=#5b3928 gui=NONE
hi Search ctermfg=NONE ctermbg=58 cterm=NONE guifg=NONE guibg=#5b3928 gui=NONE
hi Directory ctermfg=74 ctermbg=NONE cterm=NONE guifg=#34a2d9 guibg=NONE gui=NONE
hi Folded ctermfg=241 ctermbg=235 cterm=NONE guifg=#666666 guibg=#232323 gui=NONE

hi Normal ctermfg=188 ctermbg=235 cterm=NONE guifg=#e6e1dc guibg=#232323 gui=NONE
hi Boolean ctermfg=68 ctermbg=NONE cterm=NONE guifg=#3399cc guibg=NONE gui=NONE
hi Character ctermfg=74 ctermbg=NONE cterm=NONE guifg=#34a2d9 guibg=NONE gui=NONE
hi Comment ctermfg=241 ctermbg=NONE cterm=NONE guifg=#666666 guibg=NONE gui=italic
hi Conditional ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi Constant ctermfg=74 ctermbg=NONE cterm=NONE guifg=#34a2d9 guibg=NONE gui=NONE
hi Define ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi ErrorMsg ctermfg=15 ctermbg=160 cterm=NONE guifg=#ffffff guibg=#cc0000 gui=NONE
hi WarningMsg ctermfg=15 ctermbg=160 cterm=NONE guifg=#ffffff guibg=#cc0000 gui=NONE
hi Float ctermfg=113 ctermbg=NONE cterm=NONE guifg=#99cc66 guibg=NONE gui=NONE
hi Function ctermfg=221 ctermbg=NONE cterm=NONE guifg=#ffcc33 guibg=NONE gui=NONE
hi Identifier ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi Keyword ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi Label ctermfg=113 ctermbg=NONE cterm=NONE guifg=#99cc33 guibg=NONE gui=NONE
hi NonText ctermfg=238 ctermbg=236 cterm=NONE guifg=#404040 guibg=#2d2d2c gui=NONE
hi Number ctermfg=113 ctermbg=NONE cterm=NONE guifg=#99cc66 guibg=NONE gui=NONE
hi Operator ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi PreProc ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi Special ctermfg=188 ctermbg=NONE cterm=NONE guifg=#e6e1dc guibg=NONE gui=NONE
hi SpecialKey ctermfg=238 ctermbg=59 cterm=NONE guifg=#404040 guibg=#373636 gui=NONE
hi Statement ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi StorageClass ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi String ctermfg=113 ctermbg=NONE cterm=NONE guifg=#99cc33 guibg=NONE gui=NONE
hi Tag ctermfg=221 ctermbg=NONE cterm=NONE guifg=#ffcc33 guibg=NONE gui=NONE
hi Title ctermfg=188 ctermbg=NONE cterm=bold guifg=#e6e1dc guibg=NONE gui=bold
hi Todo ctermfg=241 ctermbg=NONE cterm=inverse,bold guifg=#666666 guibg=NONE gui=inverse,bold,italic
hi Type ctermfg=15 ctermbg=NONE cterm=NONE guifg=#ffffff guibg=NONE gui=NONE
hi Underlined ctermfg=NONE ctermbg=NONE cterm=underline guifg=NONE guibg=NONE gui=underline
hi rubyClass ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi rubyFunction ctermfg=221 ctermbg=NONE cterm=NONE guifg=#ffcc33 guibg=NONE gui=NONE
hi rubyInterpolationDelimiter ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi rubySymbol ctermfg=74 ctermbg=NONE cterm=NONE guifg=#34a2d9 guibg=NONE gui=NONE
hi rubyConstant ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi rubyStringDelimiter ctermfg=113 ctermbg=NONE cterm=NONE guifg=#99cc33 guibg=NONE gui=NONE
hi rubyBlockParameter ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi rubyInstanceVariable ctermfg=68 ctermbg=NONE cterm=NONE guifg=#3399cc guibg=NONE gui=NONE
hi rubyInclude ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi rubyGlobalVariable ctermfg=68 ctermbg=NONE cterm=NONE guifg=#3399cc guibg=NONE gui=NONE
hi rubyRegexp ctermfg=113 ctermbg=NONE cterm=NONE guifg=#99cc33 guibg=NONE gui=NONE
hi rubyRegexpDelimiter ctermfg=113 ctermbg=NONE cterm=NONE guifg=#99cc33 guibg=NONE gui=NONE
hi rubyEscape ctermfg=71 ctermbg=NONE cterm=NONE guifg=#519f50 guibg=NONE gui=NONE
hi rubyControl ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi rubyClassVariable ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi rubyOperator ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi rubyException ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi rubyPseudoVariable ctermfg=68 ctermbg=NONE cterm=NONE guifg=#3399cc guibg=NONE gui=NONE
hi rubyRailsUserClass ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi rubyRailsARAssociationMethod ctermfg=167 ctermbg=NONE cterm=NONE guifg=#da4939 guibg=NONE gui=NONE
hi rubyRailsARMethod ctermfg=167 ctermbg=NONE cterm=NONE guifg=#da4939 guibg=NONE gui=NONE
hi rubyRailsRenderMethod ctermfg=167 ctermbg=NONE cterm=NONE guifg=#da4939 guibg=NONE gui=NONE
hi rubyRailsMethod ctermfg=167 ctermbg=NONE cterm=NONE guifg=#da4939 guibg=NONE gui=NONE
hi erubyDelimiter ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi erubyComment ctermfg=241 ctermbg=NONE cterm=NONE guifg=#666666 guibg=NONE gui=italic
hi erubyRailsMethod ctermfg=167 ctermbg=NONE cterm=NONE guifg=#da4939 guibg=NONE gui=NONE
hi htmlTag ctermfg=221 ctermbg=NONE cterm=NONE guifg=#ffcc33 guibg=NONE gui=NONE
hi htmlEndTag ctermfg=221 ctermbg=NONE cterm=NONE guifg=#ffcc33 guibg=NONE gui=NONE
hi htmlTagName ctermfg=221 ctermbg=NONE cterm=NONE guifg=#ffcc33 guibg=NONE gui=NONE
hi htmlArg ctermfg=221 ctermbg=NONE cterm=NONE guifg=#ffcc33 guibg=NONE gui=NONE
hi htmlSpecialChar ctermfg=74 ctermbg=NONE cterm=NONE guifg=#34a2d9 guibg=NONE gui=NONE
hi javaScriptFunction ctermfg=167 ctermbg=NONE cterm=NONE guifg=#cc6633 guibg=NONE gui=NONE
hi javaScriptRailsFunction ctermfg=167 ctermbg=NONE cterm=NONE guifg=#da4939 guibg=NONE gui=NONE
hi javaScriptBraces ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi yamlKey ctermfg=221 ctermbg=NONE cterm=NONE guifg=#ffcc33 guibg=NONE gui=NONE
hi yamlAnchor ctermfg=68 ctermbg=NONE cterm=NONE guifg=#3399cc guibg=NONE gui=NONE
hi yamlAlias ctermfg=68 ctermbg=NONE cterm=NONE guifg=#3399cc guibg=NONE gui=NONE
hi yamlDocumentHeader ctermfg=113 ctermbg=NONE cterm=NONE guifg=#99cc33 guibg=NONE gui=NONE
hi cssURL ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi cssFunctionName ctermfg=167 ctermbg=NONE cterm=NONE guifg=#da4939 guibg=NONE gui=NONE
hi cssColor ctermfg=74 ctermbg=NONE cterm=NONE guifg=#34a2d9 guibg=NONE gui=NONE
hi cssPseudoClassId ctermfg=221 ctermbg=NONE cterm=NONE guifg=#ffcc33 guibg=NONE gui=NONE
hi cssClassName ctermfg=221 ctermbg=NONE cterm=NONE guifg=#ffcc33 guibg=NONE gui=NONE
hi cssValueLength ctermfg=113 ctermbg=NONE cterm=NONE guifg=#99cc66 guibg=NONE gui=NONE
hi cssCommonAttr ctermfg=113 ctermbg=NONE cterm=NONE guifg=#99cc33 guibg=NONE gui=NONE
hi cssBraces ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
