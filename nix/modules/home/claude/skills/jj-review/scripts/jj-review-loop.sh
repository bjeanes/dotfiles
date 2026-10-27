#!/usr/bin/env bash
# Review each change in a revset in revdiff, oldest first, opening the next as
# soon as the last closes. Each review's annotations are saved to
# OUT_DIR/<n>-<change>.out, then all of them are printed at the end.
set -euo pipefail

revset=${1:?usage: jj-review-loop.sh REVSET OUT_DIR}
out=${2:?usage: jj-review-loop.sh REVSET OUT_DIR}

here=$(dirname "$0")
launcher=@launcher@

mkdir -p "$out"
mapfile -t ids < <(jj log -r "$revset" --reversed --no-graph -T 'change_id.short(8) ++ "\n"')
total=${#ids[@]}

# Generate every diff up front, so each review opens immediately and all of
# them show the range as it was when the loop started.
for i in "${!ids[@]}"; do
  printf -v n '%02d' $((i + 1))
  "$here/jj-change-diff.sh" "${ids[$i]}" > "$out/$n-${ids[$i]}.diff"
done

for i in "${!ids[@]}"; do
  printf -v n '%02d' $((i + 1))
  id=${ids[$i]}
  subject=$(jj log -r "$id" --no-graph -T 'description.first_line()')
  rc=0
  "$launcher" "--stdin-file=$out/$n-$id.diff" \
    "--description=Change $((i + 1)) of $total: $id — $subject" > "$out/$n-$id.out" || rc=$?
  if [[ $rc -ne 0 && $rc -ne 10 ]]; then
    echo "Stopped at change $((i + 1)) of $total ($id): revdiff exited with $rc" >&2
    break
  fi
  # revdiff takes Ctrl-C itself, so an annotation reading just "stop" is how
  # a reviewer ends the loop early
  if grep -qix 'stop' "$out/$n-$id.out"; then
    echo "Stopped at change $((i + 1)) of $total ($id) on request" >&2
    break
  fi
done

for f in "$out"/*.out; do
  [[ -s $f ]] || continue
  printf '# %s\n\n' "$(basename "$f" .out)"
  cat "$f"
  echo
done
