# Run from the root of a clone of this flake, with `branch_dir` set to a
# checkout of the platform's branch, by convention `dotfiles-linux` or
# `dotfiles-darwin`. DOTFILES_SYSTEM is the Nix system to render for.

repo=$(git rev-parse --show-toplevel)
source_repo=${SOURCE_REPO:-bjeanes/dotfiles}
system=${DOTFILES_SYSTEM:-x86_64-linux}
case $system in
  *-darwin) platform=darwin ;;
  *) platform=linux ;;
esac
progress_ref=refs/dotfiles/$platform

# Prints the store path of SOURCE's Home Manager config, rendered by the
# `dotfiles` package of RENDERER.
render() { # renderer source
  nix build --no-link --print-out-paths --impure --expr "
    (builtins.getFlake \"git+file://$repo?rev=$1\").packages.$system.dotfiles.render
      (builtins.getFlake \"git+file://$repo?rev=$2\")
  "
}

# Replaces the branch's files with OUT and commits them as generated from REV,
# with REV's author and date, unless nothing changed.
commit_render() { # out rev [subject]
  find "$branch_dir" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  cp -R "$1"/. "$branch_dir"/
  chmod -R u+w "$branch_dir"
  # --force, so that the user's global ignores can't leave files out.
  git -C "$branch_dir" add --all --force

  if git -C "$branch_dir" diff --cached --quiet; then
    echo "  no change" >&2
  else
    GIT_AUTHOR_NAME=$(git log -1 --format=%an "$2") \
      GIT_AUTHOR_EMAIL=$(git log -1 --format=%ae "$2") \
      GIT_AUTHOR_DATE=$(git log -1 --format=%aI "$2") \
      git -C "$branch_dir" commit --quiet \
      -m "${3:-$(git log -1 --format=%s "$2")}" \
      -m "Generated from $source_repo@$2"
  fi
}
