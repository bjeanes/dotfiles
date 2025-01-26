#
# My take on https://github.com/sunlei/zsh-ssh/
#
# Pros:
#
# - Simpler ssh_config parser which successfully parses my Nix-generated file
# - Uses `ssh -G` to map `Host` -> `HostName`, where sunlei's version mismatched them
# - Simpler ZLE handling which seems to work for at least the way I use shell
#
# Cons:
#
# - Uses `ssh -G` to map `Host` -> `HostName`, and this has to be done upfront
#   so there is a noticeable delay before showing the list.
#
# TODO:
#
# - Handle `Host`s with `*` such that accepting an entry removes the `*` but
#   places the cursor input where it would have been.
#
setopt no_beep # don't beep

SSH_CONFIG_FILE="${SSH_CONFIG_FILE:-$HOME/.ssh/config}"

function _zsh_ssh_config_process_includes {
  local file="${1:-$SSH_CONFIG_FILE}"
  if [[ ! -r "$file" ]]; then
    return
  fi
  while IFS= read -r line; do
    if echo "$line" | grep -iq '^[[:space:]]*Include[[:space:]]\+'; then
      local includes=($(echo "$line" | sed -E 's/^[[:space:]]*Include[[:space:]]+//I; s/[[:space:]]+/ /g'))
      for include in "${includes[@]}"; do
        eval "included_files=($include)" 2>/dev/null
        for included_file in "${included_files[@]}"; do
          _zsh_ssh_config_process_includes "$included_file"
        done
      done
    else
      echo "$line"
    fi
  done < "$file" < <(echo)
}

function _zsh_ssh_config_host_list {
  local file="${1:-$SSH_CONFIG_FILE}"

  _zsh_ssh_config_process_includes "$file" | awk '
    BEGIN { in_match = 0; IGNORECASE = 1; }
    /^\s*Host\s+/ {
        in_match = 0;
        if ($2 == "*") {
            next;
        }
        for (i = 2; i <= NF; i++) {
            print $i;
        }
        next;
    }
    /^\s*Match\s+/ {
        in_match = 1;
        next;
    }
    in_match && /^host\s*=\s*/ {
        split($0, arr, "=");
        split(arr[2], hosts, " ");
        for (i in hosts) {
            print hosts[i];
        }
    }
  ' | awk '
    /^[a-zA-Z]/ { print $0 | "sort -u" }
    /^[0-9]/ { numbers[NR] = $0 }
    END {
      for (i in numbers) {
        print numbers[i]
      }
    }
  '
}

function _zsh_ssh_default_host_config {
  ssh -T -Fnone -G "bogus.$RANDOM" 2>/dev/null | sort
}

function _zsh_ssh_config_print_table {
  local file="${1:-$SSH_CONFIG_FILE}"
  local hosts=($(_zsh_ssh_config_host_list "$file"))
  local default_config=$(_zsh_ssh_default_host_config)

  local output="
Host|Destination|User
────|───────────|────
"

  for host in "${hosts[@]}"; do
    local config=$(comm -13 <(echo $default_config) <(ssh -G "$host" 2>/dev/null | sort))
    local destination=$(echo "$config" | awk '/^hostname / {print $2}')
    local user=$(echo "$config" | awk '/^user / {print $2}')

    [[ "$destination" == "$host" ]] && destination=""

    output+="$host|$destination|$user\n"
  done

  echo -e "$output" | _zsh_ssh__column '|'
}

# `column` command does not work well with missing/blank values. This ensures that columns after a blank value are still
# correctly aligned.
function _zsh_ssh__column {
  fs=${1:-"|"}
  sp=${2:-"5"}
  awk -F$fs '
    {
      if (NF > max_fields) max_fields = NF
      for (i = 1; i <= NF; i++) {
        field_lengths[i] = (length($i) > field_lengths[i]) ? length($i) : field_lengths[i]
      }
      lines[NR] = $0
    }
    END {
      for (i = 1; i <= NR; i++) {
        split(lines[i], fields, FS)
        for (j = 1; j <= max_fields; j++) {
          printf "%-*s", field_lengths[j] + '$sp', fields[j]
        }
        print ""
      }
    }'
}

function fzf_complete_ssh {
  local tokens cmd query result
  setopt localoptions noshwordsplit noksh_arrays noposixbuiltins

  tokens=(${(z)LBUFFER})
  cmd=${tokens[1]}

  if [[ "$cmd" != "ssh" ]]; then
    # If the command isn't `ssh`, then delegate to other completion
    zle ${fzf_ssh_default_completion:-expand-or-complete}
  elif [[ "$LBUFFER" =~ "^ *ssh$" ]]; then
    # if cursor is still on `ssh` word, then delegate to other autocompletion (e.g. ssh-keygen, ssh-import-id, etc.)
    zle ${fzf_ssh_default_completion:-expand-or-complete}
  else
    result=$(_zsh_ssh_config_print_table)
    query=()

    for arg in "${tokens[@]:1}"; do
      case $arg in
        -*) shift;;
        *) query+=($arg);;
      esac
    done

    result=$(echo "$result" | fzf \
      --height 40% \
      --ansi \
      --border \
      --cycle \
      --select-1 \
      --info=inline \
      --header-lines=3 \
      --nth=1..2 \
      --delimiter='\s+' \
      --reverse \
      --prompt='SSH Remote > ' \
      --query="${query[@]}" \
      --no-separator \
      --bind 'shift-tab:up,tab:down,bspace:backward-delete-char/eof' \
      --preview 'comm -13 <(ssh -T -Fnone -G 'bogus.$RANDOM' | sort) <(ssh -T -G $(cut -f 1 -d " " <<< {}) | sort) | awk '\''{printf "%-20s %s\n", $1, substr($0, index($0,$2))}'\'' ' \
      --preview-window=right:40% | \
      awk '{print $1}'
    )

    if [[ -n "$result" ]]; then
      LBUFFER="${LBUFFER% *} $result"
      zle redisplay
      # zle accept-line
    fi

    zle reset-prompt
  fi
}

[ -z "$fzf_ssh_default_completion" ] && {
  binding=$(bindkey '^I')
  [[ $binding =~ 'undefined-key' ]] || fzf_ssh_default_completion=$binding[(s: :w)2]
  unset binding
}

zle -N fzf_complete_ssh
bindkey '^I' fzf_complete_ssh
