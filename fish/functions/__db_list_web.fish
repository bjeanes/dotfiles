function __db_list_web
	switch (__detect_webapp)
    case rails merb merb_bundle
      parse_database_yml.rb config/database.yml
    case '*'
  end

end
