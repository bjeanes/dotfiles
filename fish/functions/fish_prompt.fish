# function fish_prompt --description 'Write out the prompt'
#   set pr_timestamp (date '+%a %H:%M:%S')
#   set pr_user (whoami)
#   set pr_host (hostname | cut -d . -f 1)
#   set pr_cwd (prompt_pwd)
#   set pr_git_info (git_cwd_info)
#   printf "\033[90m$pr_timestamp\033[0m $pr_user\033[90m@\033[0m$pr_host \033[90m$pr_cwd\033[0m \033[32m>\033[0m "
# end

function fish_prompt --description 'Write out the prompt'
  printf '%s%s@%s%s ' (set_color green) (whoami) (hostname|cut -d . -f 1) (set_color normal) 
 
  # Write the process working directory
  if test -w "."
    printf '%s%s' (set_color -o $fish_color_cwd) (prompt_pwd)
  else
    printf '%s%s' (set_color -o $fish_color_uneditable_cwd) (prompt_pwd)
  end
 
  printf '%s%s ' (set_color red) (__git_ps1)

  if git_dirty
    printf '%s☠ ' (set_color red)
  end
 
  printf '%s$%s ' (set_color -o $fish_color_cwd) (set_color normal)
 
  printf '%s> ' (set_color normal)
end