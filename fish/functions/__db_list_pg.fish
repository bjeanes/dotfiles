function __db_list_pg
	psql -c '\l' -t -A -F, | cut -d, -f1 | grep -E -v '^(postgres|template)'
  __db_list_web | grep -E '^postgres' | cut -f2

end
