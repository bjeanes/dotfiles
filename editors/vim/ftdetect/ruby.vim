" Ruby
au BufNewFile,BufRead *.rb,*.rbw,*.gem,*.gemspec set filetype=ruby

" Ruby on Rails
au BufNewFile,BufRead *.builder,*.rxml,*.rjs set filetype=ruby

" Rakefile
au BufNewFile,BufRead [rR]akefile,*.rake set filetype=ruby

" IRB config
au BufNewFile,BufRead .irbrc,irbrc set filetype=ruby

" eRuby
au BufNewFile,BufRead *.erb,*.rhtml set filetype=eruby

" Thorfile
au BufNewFile,BufRead [tT]horfile,*.thor set filetype=ruby

" Gemfile
au BufNewFile,BufRead Gemfile set filetype=ruby

" Rackup
au BufNewFile,BufRead config.ru set filetype=ruby
