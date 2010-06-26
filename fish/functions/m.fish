function m
	if not test $argv
		set argv .
	end
	mate -l1 $argv ^/dev/null
end
