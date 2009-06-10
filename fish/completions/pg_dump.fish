complete -x -c pg_dump -d postgres -a "(__db_list_pg | uniq)"
