function command_status_color
  if test (whoami) = "root"
    echo (set_color red)
  else
    echo (set_color green)
  end
end