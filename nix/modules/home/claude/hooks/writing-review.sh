input=$(cat)
session=$(jq -r '.session_id' <<<"$input")
command=$(jq -r '.tool_input.command' <<<"$input")

# Only commands that write text: a jj message, or a gh title, body or comment
if ! grep -Eq -- '(^|[[:space:]])(-m|--message|--stdin)([[:space:]=]|$)|body|--title|(^|[[:space:]])-t[[:space:]]' <<<"$command"; then
  exit 0
fi

# Running the same command again is how the agent says it has checked the
# text. A revised command is new text, and gets its own reminder.
seen="${TMPDIR:-/tmp}/claude-writing-review/$session"
mkdir -p "$seen"
mark="$seen/$(sha256sum <<<"$command" | cut -d' ' -f1)"
if [[ -e $mark ]]; then
  exit 0
fi
touch "$mark"

if grep -q '\bgh\b' <<<"$command" || (($(wc -l <<<"$command") > 5)); then
  check="Ask the writing-reviewer agent to check it, and say which register it is in. For a commit, also ask it to check the code comments that the revision adds. It sees only the text, so weigh its findings against what you know of the work and decide the wording yourself."
else
  check="Check it yourself against the Claude-isms in writing.md and the examples in the skill. For a commit, also check any code comments that the revision adds."
fi

reason="This command writes text under the user's name. Before it runs, load the write-as-me skill if it isn't loaded already. $check Revise the text if it needs it, then run the command again. Running the same command again unchanged lets it through."

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
