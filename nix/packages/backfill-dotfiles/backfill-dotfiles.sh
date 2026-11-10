# Renders this flake's history from FIRST onwards into a checkout of the
# `dotfiles` branch, one commit per commit that changes the result. Run it from
# the root of a clone of this flake. It never pushes.
#
# Usage: backfill-dotfiles BRANCH_DIR FIRST
#
# BRANCH_DIR starts out empty, such as a worktree added with --orphan. If it
# already has commits, the run resumes like publish-dotfiles does instead.
#
# Unlike publish-dotfiles, if a commit fails to render, the run goes on. The
# commit is retried as described at `render_rev_only`, or else skipped and
# listed at the end.

branch_dir=$(realpath "$1")
head=$(git rev-parse HEAD)
skipped=()

# Some commits pin an input by both `ref` and `rev`, which newer Nix rejects.
# This renders a copy of REV with only the `rev`, made without a worktree.
render_rev_only() { # rev
  local index flake lock tree copy
  index=$(mktemp)
  flake=$(git show "$1:flake.nix" | sed '/^\s*ref = "[^"]*";$/d' | git hash-object -w --stdin)
  lock=$(git show "$1:flake.lock" |
    jq '.nodes |= map_values(
          if .original.type == "github" and .original.rev and .original.ref
          then .original |= del(.ref) else . end)' |
    git hash-object -w --stdin)
  GIT_INDEX_FILE=$index git read-tree "$1"
  GIT_INDEX_FILE=$index git update-index --cacheinfo "100644,$flake,flake.nix"
  GIT_INDEX_FILE=$index git update-index --cacheinfo "100644,$lock,flake.lock"
  tree=$(GIT_INDEX_FILE=$index git write-tree)
  rm "$index"
  copy=$(GIT_AUTHOR_NAME=backfill-dotfiles GIT_AUTHOR_EMAIL=backfill-dotfiles \
    GIT_COMMITTER_NAME=backfill-dotfiles GIT_COMMITTER_EMAIL=backfill-dotfiles \
    git commit-tree "$tree" -p "$1" -m "$1 with only the rev of each input")

  render "$head" "$copy"
}

# Prints the render of REV, or of a rev-only copy if Nix rejected REV's pins.
render_any() { # rev
  local err status=0
  err=$(mktemp)
  { render "$head" "$1" 2>&1 1>&3 | tee "$err" >&2; } 3>&1 || status=$?
  if [ "$status" -ne 0 ] && grep -q 'contains both a commit hash' "$err"; then
    echo "  retrying with only the rev of each input" >&2
    status=0
    render_rev_only "$1" || status=$?
  fi
  rm "$err"
  return "$status"
}

if git -C "$branch_dir" rev-parse --verify --quiet HEAD >/dev/null; then
  last=$(git rev-parse --verify --quiet "$progress_ref" ||
    git -C "$branch_dir" log -1 --format=%B |
    sed -n 's/^Generated from [^@ ]*@\([0-9a-f]\{40\}\)$/\1/p')
  [ -n "$last" ] || {
    echo "can't tell where $branch_dir left off" >&2
    exit 1
  }
else
  last=""
  for rev in $(git rev-list --reverse --first-parent "$2^..$head"); do
    echo "rendering $(git log -1 --format='%h %s' "$rev")" >&2
    if out=$(render_any "$rev"); then
      commit_render "$out" "$rev" "Render the Nix dotfiles into their own branch"
      git update-ref "$progress_ref" "$rev"
      last=$rev
      break
    fi
    echo "  skipped" >&2
    skipped+=("$(git log -1 --format='%h %ad %s' --date=short "$rev")")
  done
  [ -n "$last" ] || exit 1
fi
revs=$(git rev-list --reverse --first-parent "$last..$head")

for rev in $revs; do
  echo "rendering $(git log -1 --format='%h %s' "$rev")" >&2
  if out=$(render_any "$rev"); then
    commit_render "$out" "$rev"
  else
    echo "  skipped" >&2
    skipped+=("$(git log -1 --format='%h %ad %s' --date=short "$rev")")
  fi
  git update-ref "$progress_ref" "$rev"
done

if [ ${#skipped[@]} -gt 0 ]; then
  echo "Skipped ${#skipped[@]} commit(s) that wouldn't render:" >&2
  printf '  %s\n' "${skipped[@]}" >&2
fi
