function c
	switch (__detect_webapp)
    case rails
      ./script/console $argv
    case sinatra
      irb -r (__sinatra_app)
    case merb_bundle
      ./bin/merb -i $argv
    case merb
      merb -i $argv
    case '*'
      echo "doesn't look like you're in a web app... using plain ol' irb"
      irb
  end

end
