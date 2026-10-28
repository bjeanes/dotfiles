#!/usr/bin/env bash
# Review each change in a revset in revdiff, oldest first, opening the next as
# soon as the last closes. Each change's annotations are saved to
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
  : > "$out/$n-${ids[$i]}.out"
done

# Prints a visit's annotations, except those that only steer the loop (whose
# whole text is "prev" or "stop"). Their words go to the file named by $2.
split_controls() {
  awk -v controls="$2" '
    function flush(  word) {
      word = tolower(body)
      gsub(/[[:space:]]/, "", word)
      if (word == "prev" || word == "stop") {
        print word > controls
      } else if (block != "") {
        sub(/\n+$/, "\n", block)
        printf "%s\n", block
      }
      block = ""; body = ""
    }
    /^## / { flush() }
    { block = block $0 "\n" }
    !/^## / && /[^[:space:]]/ { body = body $0 }
    END { flush() }
  ' "$1"
}

# revdiff takes Ctrl-C itself and can't navigate between separate diffs, so a
# reviewer steers the loop with an annotation reading just "stop" or "prev"
i=0
while ((i < total)); do
  printf -v n '%02d' $((i + 1))
  id=${ids[$i]}
  subject=$(jj log -r "$id" --no-graph -T 'description.first_line()')
  # revdiff can't preload annotations alongside --stdin, so a revisit starts
  # empty, and its annotations are added to the earlier ones
  kept=$(grep -c '^## ' "$out/$n-$id.out" || true)
  note=
  if ((kept > 0)); then
    note=" (earlier annotations kept: $kept)"
  fi

  rc=0
  "$launcher" "--stdin-file=$out/$n-$id.diff" \
    "--description=Change $((i + 1)) of $total: $id — $subject$note" > "$out/visit" || rc=$?
  if [[ $rc -ne 0 && $rc -ne 10 ]]; then
    echo "Stopped at change $((i + 1)) of $total ($id): revdiff exited with $rc" >&2
    break
  fi
  : > "$out/controls"
  split_controls "$out/visit" "$out/controls" >> "$out/$n-$id.out"

  if grep -qx 'stop' "$out/controls"; then
    echo "Stopped at change $((i + 1)) of $total ($id) on request" >&2
    break
  elif grep -qx 'prev' "$out/controls"; then
    i=$((i > 0 ? i - 1 : 0))
  else
    i=$((i + 1))
  fi
done
rm -f "$out/visit" "$out/controls"

for f in "$out"/*.out; do
  [[ -s $f ]] || continue
  printf '# %s\n\n' "$(basename "$f" .out)"
  cat "$f"
done
