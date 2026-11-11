# Combines the `dotfiles-linux` and `dotfiles-darwin` branches into
# `dotfiles`, with one commit per commit on HEAD's first-parent history that
# changes either platform. Each platform's files go under linux/ or darwin/ in
# full, even those that are the same on both. Run it from the root of a clone of
# this flake, with both branches present. It needs no checkout. It never pushes.
#
# It starts at the first commit either platform has rendered. Until the other
# platform's first render, its directory is left out. If `dotfiles` already
# exists, it resumes after the commit its tip was generated from.

shopt -s inherit_errexit

source_repo=${SOURCE_REPO:-bjeanes/dotfiles}
out=refs/heads/dotfiles

generated_from() { # commit
  git log -1 --format=%B "$1" | sed -n 's/^Generated from [^@ ]*@\([0-9a-f]\{40\}\)$/\1/p'
}

# Source commit => the tree of each platform's snapshot generated from it.
declare -A linux darwin
while read -r commit; do
  linux[$(generated_from "$commit")]=$(git rev-parse "$commit^{tree}")
done < <(git rev-list refs/heads/dotfiles-linux)
while read -r commit; do
  darwin[$(generated_from "$commit")]=$(git rev-parse "$commit^{tree}")
done < <(git rev-list refs/heads/dotfiles-darwin)

# Either tree may be empty, before that platform's first render.
combined_tree() { # linux darwin
  local index readme
  index=$(mktemp)
  GIT_INDEX_FILE=$index git read-tree --empty
  [ -z "$1" ] || GIT_INDEX_FILE=$index git read-tree --prefix=linux/ "$1"
  [ -z "$2" ] || GIT_INDEX_FILE=$index git read-tree --prefix=darwin/ "$2"
  # GitHub only shows a README on the branch's front page if it's at the root.
  if readme=$(git rev-parse --verify --quiet "${1:-$2}:README.md"); then
    GIT_INDEX_FILE=$index git update-index --add --cacheinfo "100644,$readme,README.md"
  fi
  GIT_INDEX_FILE=$index git write-tree
  rm "$index"
}

resume_after=""
parent=""
if git rev-parse --verify --quiet "$out" >/dev/null; then
  parent=$(git rev-parse "$out")
  resume_after=$(generated_from "$parent")
fi

linux_tree="" darwin_tree="" last_tree="" stitching=""
[ -z "$resume_after" ] || stitching=resuming
[ -z "$parent" ] || last_tree=$(git rev-parse "$parent^{tree}")

for rev in $(git rev-list --reverse --first-parent HEAD); do
  arrived=""
  [ -n "$linux_tree" ] || [ -z "${linux[$rev]-}" ] || arrived=Linux
  [ -n "$darwin_tree" ] || [ -z "${darwin[$rev]-}" ] || arrived=macOS
  linux_tree=${linux[$rev]:-$linux_tree}
  darwin_tree=${darwin[$rev]:-$darwin_tree}

  if [ "$stitching" = resuming ]; then
    [ "$rev" = "$resume_after" ] && stitching=yes
    continue
  fi
  [ -n "$linux_tree" ] || [ -n "$darwin_tree" ] || continue

  tree=$(combined_tree "$linux_tree" "$darwin_tree")
  [ "$tree" != "$last_tree" ] || continue

  subject=$(git log -1 --format=%s "$rev")
  # These hold everything up to here, not just this commit's change.
  [ -z "$arrived" ] || subject="Add the $arrived render"
  [ -n "$parent" ] || subject="Render the Nix dotfiles into their own branch"
  echo "stitching $(git log -1 --format='%h %s' "$rev")" >&2
  parent=$(
    GIT_AUTHOR_NAME=$(git log -1 --format=%an "$rev") \
      GIT_AUTHOR_EMAIL=$(git log -1 --format=%ae "$rev") \
      GIT_AUTHOR_DATE=$(git log -1 --format=%aI "$rev") \
      git commit-tree "$tree" ${parent:+-p "$parent"} -m "$subject" -m "Generated from $source_repo@$rev"
  )
  git update-ref "$out" "$parent"
  last_tree=$tree
done
