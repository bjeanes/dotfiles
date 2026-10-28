input=$(cat)
session=$(jq -r '.session_id' <<<"$input")
file=$(jq -r '.tool_input.file_path' <<<"$input")
inserted=$(jq -r '.tool_input | .new_string // .content // ([.edits[]?.new_string] | join("\n"))' <<<"$input")

case $file in
  *.sh | *.bash | *.zsh | *.fish | *.nix | *.rb | *.py | *.yml | *.yaml | *.toml)
    comment='(^|[[:space:]])#([[:space:]]|$)' ;;
  *.js | *.jsx | *.ts | *.tsx | *.go | *.rs | *.java | *.kt | *.swift | *.c | *.h | *.cpp | *.css | *.scss)
    comment='(^|[[:space:]])(//|/\*)' ;;
  *.lua | *.sql | *.hs)
    comment='(^|[[:space:]])--([[:space:]]|$)' ;;
  *.el | *.clj | *.lisp)
    comment='(^|[[:space:]]);' ;;
  *)
    exit 0 ;;
esac

if ! grep -Eq -- "$comment" <<<"$inserted"; then
  exit 0
fi

# Once per file, so that fixing a comment doesn't bring the reminder back
seen="${TMPDIR:-/tmp}/claude-comment-review/$session"
mkdir -p "$seen"
mark="$seen/$(sha256sum <<<"$file" | cut -d' ' -f1)"
if [[ -e $mark ]]; then
  exit 0
fi
touch "$mark"

context="That edit to $file looks like it adds a code comment. Comments are prose written under the user's name. Check any you added against the \"Code comments\" section of code.md and the Claude-isms in writing.md, and fix them if they need it. This reminder appears once per file."

jq -n --arg context "$context" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $context
  }
}'
