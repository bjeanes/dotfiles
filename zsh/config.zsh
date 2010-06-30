alias reload="source ~/.zshrc"

bindkey "\e\e[C" forward-word
bindkey "\e\e[D" backward-word

# http://www.scannedinavian.com/~shae/shae.zshrc
# These are options I've copied but yet to totally investigate if it's what I want
setopt alwaystoend             # when complete from middle, move cursor
setopt completeinword          # not just at the end
setopt correct                 # spelling correction
setopt histverify              # when using ! cmds, confirm first
setopt interactivecomments     # escape commands so i can use them later
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

# jump to each element in a path with m-f m-b, same
# for kill-word, etc.
export WORDCHARS=''

