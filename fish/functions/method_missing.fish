function method_missing --on-event fish_command_not_found
	fish_method_missing $argv
end
