function is_git_repo
	git status >/dev/null ^/dev/null
	not test $status -eq 128


end
