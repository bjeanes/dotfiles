# Renders each commit on the current branch that hasn't been rendered yet, and
# commits the result to a checkout of the platform's branch. Run it from the
# root of a clone of this flake. It never pushes.
#
# Usage: publish-dotfiles BRANCH_DIR [LAST_RENDERED]
#
# It resumes after refs/dotfiles/<platform>, or else after the commit that
# BRANCH_DIR's last commit was generated from, or else renders HEAD alone.
# LAST_RENDERED overrides both, such as to step past a commit that can't be
# rendered at all. DOTFILES_SYSTEM is the Nix system to render for (by default
# x86_64-linux), and its platform, `linux` or `darwin`, names the progress ref.
# SOURCE_REPO is the GitHub repository each commit message names its source
# commit in.

branch_dir=$(realpath "$1")
head=$(git rev-parse HEAD)

ancestor_of_head() {
  [ -n "$1" ] && git merge-base --is-ancestor "$1" "$head" 2>/dev/null
}

last_generated_from() {
  git -C "$branch_dir" log -1 --format=%B 2>/dev/null |
    sed -n 's/^Generated from [^@ ]*@\([0-9a-f]\{40\}\)$/\1/p'
}

last=""
for candidate in "${2:-}" "$(git rev-parse --verify --quiet "$progress_ref" || true)" "$(last_generated_from)"; do
  if ancestor_of_head "$candidate"; then
    last=$(git rev-parse "$candidate")
    break
  fi
done

if [ -n "$last" ]; then
  revs=$(git rev-list --reverse --first-parent "$last..$head")
else
  revs=$head
fi

for rev in $revs; do
  echo "rendering $(git log -1 --format='%h %s' "$rev")" >&2
  out=$(render "$head" "$rev")
  commit_render "$out" "$rev"
  git update-ref "$progress_ref" "$rev"
done
