function s
	switch (__detect_webapp)
    case rails
      ./script/server $argv
    case sinatra
      ruby (__sinatra_app)
    case merb_bundle
      ./bin/merb $argv
    case merb
      merb $argv
    case '*'
      echo "doesn't look like you're in a web app!"
  end
  

end
