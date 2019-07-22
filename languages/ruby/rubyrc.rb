# try_require = ->(code) do
#   begin
#     require(code)
#   rescue LoadError
#     puts "#{code} not installed"
#   end
# end
# try_require.('pry')
# try_require.('pry-doc')
# try_require.('pry-byebug')
puts "hi"
require 'bundler/inline'
gemfile(true) do
  gem 'pry'
  gem 'pry-doc'
  gem 'pry-byebug'
end
