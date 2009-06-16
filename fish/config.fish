cd $HOME ^/dev/null # for some reason $PWD is empty in new consoles

mkdir -p ~/.l

set fish_greeting ''

set path_list /usr/local/git/bin /usr/local/mysql/bin /usr/local/jruby/bin /usr/local/nginx/sbin /Library/PostgreSQL8/bin
set cd_path_list    . ~ ~/Sites ~/Code /Volumes ~/.l

for i in $path_list
	if not contains $i $PATH
		if test -d $i
			set PATH $PATH $i
		end
	end
end

for i in $cd_path_list
	if not contains $i $CDPATH
		if test -d $i
			set CDPATH $CDPATH $i
		end
	end
end

set -x EDITOR    "mate -w"
set -x VISUAL    $EDITOR
set -x GIT_EDITOR "mate -wl1" # ensures cursor is at beginning of document

set -x CLICOLOR 1
set -x JAVA_HOME "/usr/"
set -U BROWSER "open -a Safari"


bind \cr "rake"

set fish_color_git_branch green
set fish_color_cwd blue
set fish_color_uneditable_cwd red