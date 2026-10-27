#!/usr/bin/env bash
# Print one change's diff with its description prepended as a new COMMIT_MSG
# file, for `revdiff --stdin`. COMMIT_MSG opens with 5 lines of header before
# the description starts.
set -euo pipefail

id=${1:?usage: jj-change-diff.sh CHANGE}

msg=$(jj log -r "$id" --no-graph -T '
  "Change: " ++ change_id.short(12) ++ "\n" ++
  "Commit: " ++ commit_id.short(12) ++ "\n" ++
  "Parent: " ++ parents.map(|p| p.change_id().short(12) ++ " " ++ p.description().first_line()).join(", ") ++ "\n" ++
  "Author: " ++ author.name() ++ " <" ++ author.email() ++ ">\n" ++
  "\n" ++ description')
lines=$(printf '%s\n' "$msg" | wc -l | tr -d ' ')

printf 'diff --git a/COMMIT_MSG b/COMMIT_MSG\n'
printf 'new file mode 100644\n--- /dev/null\n+++ b/COMMIT_MSG\n'
printf '@@ -0,0 +1,%s @@\n' "$lines"
printf '%s\n' "$msg" | sed 's/^/+/'

jj diff -r "$id" --git --color=never
