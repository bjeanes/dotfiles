alias reload="source ~/.zshrc"

# Option-Left + Option-Right for moving word-by-word in OS X
bindkey "\e\e[C" vi-forward-word
bindkey "\e\e[D" vi-backward-word

# # forward/back directories with Option+Up/Down
# function back-dir {
#   cd -1 >/dev/null
#   echo
# }
# 
# function fwd-dir {
#   cd +1 >/dev/null
#   echo
# }
# 
# zle -N back-dir back-dir
# zle -N fwd-dir fwd-dir
# 
# bindkey "\e\e[A" back-dir
# bindkey "\e\e[B" fwd-dir

# http://www.scannedinavian.com/~shae/shae.zshrc
# These are options I've copied but yet to totally investigate if it's what I want
setopt alwaystoend             # when complete from middle, move cursor
setopt completeinword          # not just at the end
setopt correct                 # spelling correction
setopt histverify              # when using ! cmds, confirm first
setopt listpacked              # compact completion lists
setopt noautomenu              # don't cycle completions
setopt pushdignoredups         # and don't duplicate them
setopt recexact                # recognise exact, ambiguous matches
setopt nullglob

# These are options that I definitely want
setopt sharehistory
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

# jump to each element in a path with m-f m-b, same
# for kill-word, etc.
WORDCHARS=''

