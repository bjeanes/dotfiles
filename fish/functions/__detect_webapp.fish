function __detect_webapp
	if __sinatra_app > /dev/null
    echo sinatra
    return
  end
 
  if test -d 'script'
    echo rails
    return
  end
 
  if test -d 'config'
    if test -d 'bin'
      echo merb_bundle
    else
      echo merb
    end
 
    return
  end
  
  echo "unknown"

end
