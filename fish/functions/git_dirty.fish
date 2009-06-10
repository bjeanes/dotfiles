function git_dirty
	not git diff HEAD --quiet ^/dev/null

end
