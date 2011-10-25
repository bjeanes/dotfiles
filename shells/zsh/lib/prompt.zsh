autoload zsh/terminfo

pr_reset="%f%u%k%s%b" # reset all codes

if [ "$terminfo[colors]" -eq 256 ]; then
  pr_red="%F{52}"
  pr_blue="%F{25}"
  pr_green="%F{28}"
  pr_grey="%F{59}"
else
  if [ "$terminfo[colors]" -eq 8 ]; then
    pr_red="%F{red}"
    pr_blue="%F{blue}"
    pr_green="%F{green}"
    pr_grey="%B%F{black}"
  fi
fi

# VCS configuration
autoload vcs_info
zstyle ':vcs_info:*'      enable             git hg svn
zstyle ':vcs_info:*'      get-revision       true
zstyle ':vcs_info:*'      formats            "(%s) %b@%6>>%i%<<…" "%r" "%R" "%S"
zstyle ':vcs_info:*'      actionformats      "(%s) %b@%6>>%i%<<…|%U%a%%u"
zstyle ':vcs_info:*'      branchformat       "%b:%r"
zstyle ':vcs_info:hg*:*'  use-simple         true
zstyle ':vcs_info:svn:*'  formats            "(%s) %b:r%i" "%r"
zstyle ':vcs_info:svn:*'  branchformat       "%b"

# TODO:
#   - Discover root of repo based on full path, not basename (to avoid underlining multiple path components) ($vcs_info_msg_2_)
function prompt_pwd() {
  local repo="$vcs_info_msg_1_"

  parts=(${(s:/:)${${PWD}/#${HOME}/\~}})

  i=0
  while (( i++ < ${#parts} )); do
    part="$parts[i]"
    if [[ "$part" == "$repo" ]]; then
      # if this part of the path represents the repo,
      # underline it, and skip truncating the component
      parts[i]="%U$part%u"
    else
      # Shorten the path as long as it isn't the last piece
      if [[ "$parts[${#parts}]" != "$part" ]]; then
        parts[i]="$part[1,1]"
      fi
    fi
  done

  local prompt_path="${(j:/:)parts}"
  if [ "$parts[1]" != "~" ]; then
    prompt_path="/$prompt_path"
  fi
  echo "$prompt_path"
}


function prompt_pwd_new() {
  local parts path part cwd i=0
  typeset -L path


  parts=(${(s:/:)${${PWD}/#${HOME}/\~}})

  while (( i++ < ${#parts} )); do
    part="$parts[i]"

    if [[ "$part" == "~" ]]; then
      path="$part"
    else
      # This check is broken because LHS is collapsed, RHS is expanded
      if [[ "$path/$part" == "${vcs_info_msg_2_/#${HOME}/~}" ]]; then
        part="%U$part%u"
      elif [[ "$parts[${#parts}]" != "$part" ]]; then
        part="$part[1,1]"
      fi

      path="$path/$part"
    fi

    # if [[ "$part" == "$repo" ]]; then
      # # if this part of the path represents the repo,
      # # underline it, and skip truncating the component
      # parts[i]="%U$part%u"
    # else
      # # Shorten the path as long as it isn't the last piece
      # if [[ "$parts[${#parts}]" != "$part" ]]; then
        # parts[i]="$part[1,1]"
      # fi
    # fi
  done

  echo "$path"
}

function precmd {
  vcs_info

  local cwd="$pr_blue`prompt_pwd`$pr_reset"
  local char="%0(?.$pr_green.$pr_red)♪$pr_reset"
  local time="$pr_grey⌚ %*$pr_reset"

  local ruby
  which rvm-prompt &>/dev/null && ruby="❖ `rvm-prompt`"
  which rbenv      &>/dev/null && ruby="❖ `rbenv version-name`"


  local rev="$pr_grey$vcs_info_msg_0_$pr_reset"
  rev="${rev/\(git\)/±}"
  rev="${rev/\(hg\)/☿}"
  rev="${rev/\(svn\)/↯}"

  local left right
  left=($(user_at_host) $cwd $char)
  right=($rev $ruby $time)

  PS1="$left [ "
  RPS1="] $right"
}


