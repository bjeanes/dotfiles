export GEM_OPEN_EDITOR="$editor"
export IRBRC="$HOME/.irbrc"
export RBXOPT="-Xrbc.db=/tmp/rbx -X19"
export JRUBY_OPTS="--1.9"

function __database_yml {
  if [[ -f config/database.yml ]]; then
    ruby -ryaml -rerb -e "puts YAML::load(ERB.new(IO.read('config/database.yml')).result)['${RAILS_ENV:-development}']['$1']"
  fi
}

export PSQL_EDITOR='vim +"set syntax=sql"'
function psql
{
  if [[ "$(__database_yml adapter)" == 'postgresql' ]]; then
    PGDATABASE="$(__database_yml database)" "$(which psql)" "$@"
    return $?
  fi
  "$(/usr/bin/which psql)" "$@"
}
