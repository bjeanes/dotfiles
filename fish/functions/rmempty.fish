function rmempty	
	find . -depth -empty -type d -exec rmdir '{}' \;
end
