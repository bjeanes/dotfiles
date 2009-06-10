mkdir -p ~/.l

set fish_greeting ''
set -x PWD "~" # some reason this is empty in new consoles

set -x PATH      $PATH /usr/local/git/bin /usr/local/mysql/bin /usr/local/jruby/bin
set -x CDPATH    . ~ ~/Sites ~/Code /Volumes ~/.l

set -x EDITOR    "mate -w"
set -x VISUAL    $EDITOR
set -x GITEDITOR $EDITOR

set -x CLICOLOR 1
set -x JAVA_HOME "/usr/"
set -U BROWSER "open -a Safari"


bind \cr "rake"

set fish_color_git_branch green
set fish_color_cwd blue
set fish_color_uneditable_cwd red