# Renders each commit on the current branch that hasn't been rendered yet, and
# commits the result to a checkout of the `dotfiles` branch. Run it from the
# root of a clone of this flake. It never pushes.
#
# Usage: publish-dotfiles BRANCH_DIR [LAST_RENDERED]
#
# It resumes after refs/dotfiles/rendered, or else after the commit that
# BRANCH_DIR's last commit was generated from, or else renders HEAD alone.
# LAST_RENDERED overrides both, such as to step past a commit that can't be
# rendered at all. SOURCE_REPO is the GitHub repository each commit message
# names its source commit in.

branch_dir=$(realpath "$1")
repo=$(git rev-parse --show-toplevel)
source_repo=${SOURCE_REPO:-bjeanes/dotfiles}
progress_ref=refs/dotfiles/rendered
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
  out=$(nix build --no-link --print-out-paths --impure --expr "
    (builtins.getFlake \"git+file://$repo?rev=$head\").packages.x86_64-linux.dotfiles.render
      (builtins.getFlake \"git+file://$repo?rev=$rev\")
  ")

  find "$branch_dir" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  cp -R "$out"/. "$branch_dir"/
  chmod -R u+w "$branch_dir"
  # --force, so that the user's global ignores can't leave files out.
  git -C "$branch_dir" add --all --force

  if git -C "$branch_dir" diff --cached --quiet; then
    echo "  no change" >&2
  else
    GIT_AUTHOR_NAME=$(git log -1 --format=%an "$rev") \
      GIT_AUTHOR_EMAIL=$(git log -1 --format=%ae "$rev") \
      GIT_AUTHOR_DATE=$(git log -1 --format=%aI "$rev") \
      git -C "$branch_dir" commit --quiet \
      -m "$(git log -1 --format=%s "$rev")" \
      -m "Generated from $source_repo@$rev"
  fi

  git update-ref "$progress_ref" "$rev"
done
