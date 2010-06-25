function fish_prompt --description 'Write out the prompt'
  set -l prompt (color_print (command_status_color) '♪'                  )
  set -l date   (color_print (set_color white)      (date '+%a %H:%M:%S'))
  set -l git    (color_print (set_color red)        (__git_ps1))
  set -l pwd    (prompt_pwd)
  
	echo (printf '%s%s' $pwd $git) "$prompt "
end
