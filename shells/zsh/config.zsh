alias reload="source ~/.zshrc"

[[ $EMACS = t ]] && unsetopt zle

fpath=($SHELL_FILES/completions $fpath)

# Option-Left + Option-Right for moving word-by-word in OS X
bindkey "\e\e[C" vi-forward-word
bindkey "\e\e[D" vi-backward-word

# http://www.scannedinavian.com/~shae/shae.zshrc
# These are options I've copied but yet to totally investigate if it's what I want
setopt alwaystoend             # when complete from middle, move cursor
setopt completeinword          # not just at the end
setopt correct                 # spelling correction
setopt listpacked              # compact completion lists
setopt noautomenu              # don't cycle completions
setopt pushdignoredups         # and don't duplicate them
setopt recexact                # recognise exact, ambiguous matches
setopt nullglob

# These are options that I definitely want
setopt sharehistory
setopt histverify              # when using ! cmds, confirm first
setopt correct                 # spelling correction
setopt rmstarwait              # if `rm *` wait 10 seconds before performing it!
setopt notify                  # notify of BG job completion immediately
setopt printexitvalue          # alert me if something's failed
setopt autocd                  # change to dirs without cd
setopt autopushd               # automatically append dirs to the push/pop list
setopt cdablevars              # avoid the need for an explicit $
setopt nobeep                  # i hate beeps
setopt nohup                   # and don't kill BG jobs when shell exits
setopt extendedglob            # awesome pattern matching (ala Dir.glob() in Ruby)
setopt promptcr                # ensure a new line before prompt is drawn
setopt listtypes               # show types in completion
setopt nocompletealiases       # Allows alias 'ga' to use 'git add' completions (for example)
setopt interactivecomments     # escape commands so i can use them later
setopt sh_word_split           # commands will be split on space (i.e. $VISUAL = "mate -wl1" will work)

# Allow kill word and moving forward/backword by word to behave like bash (e.g. stop at / chars)
autoload -U select-word-style
select-word-style bash

REPORTTIME=2
TIMEFMT="%*Es total, %U user, %S system, %P cpu"
