function __db_list
	switch $argv[1]
    case "pg"
      __db_list_pg | uniq
    case "mysql"
  end

end
