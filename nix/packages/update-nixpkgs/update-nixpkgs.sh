# Dry-runs every NixOS and nix-darwin host in this flake against each recent
# nixos-unstable release, newest first. Locks nixpkgs to the first release
# that every host can evaluate and fetch from cache.nixos.org. Run it from the
# root of the flake.

shopt -s inherit_errexit

releases=https://releases.nixos.org/nixos/unstable
max_candidates=10
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

log() { echo "$@" >&2; }

# Reads .drv store paths and prints "pname path" for each, splitting the
# version off the way builtins.parseDrvName does.
pnames() {
  sed -E 's|^(/nix/store/.{32}-(.*)\.drv)$|\2 \1|; s/-[0-9][^ ]* / /'
}

cached() { # store path
  curl -fsI -o /dev/null "https://cache.nixos.org/$(basename "$1" | cut -c1-32).narinfo"
}

locked_rev=$(jq -r '.nodes[.nodes.root.inputs.nixpkgs].locked.rev' flake.lock)
locked_time=$(jq -r '.nodes[.nodes.root.inputs.nixpkgs].locked.lastModified' flake.lock)
log "locked: $locked_rev ($(date -d "@$locked_time" +%F))"

attrs=()
while read -r host; do
  attrs+=(".#nixosConfigurations.$host.config.system.build.toplevel")
done < <(nix eval --json .#nixosConfigurations --apply builtins.attrNames 2>/dev/null | jq -r '.[]')
while read -r host; do
  attrs+=(".#darwinConfigurations.$host.system")
done < <(nix eval --json .#darwinConfigurations --apply builtins.attrNames 2>/dev/null |
  jq -r '.[] | select(endswith("-bootstrap") | not)')

# Every release of the channel gets a directory such as
# nixos-26.11pre1119549.d5cc68339997, numbered in the order they were made. We
# only list those sharing the latest release's series prefix.
latest=$(curl -fsSI https://channels.nixos.org/nixos-unstable | sed -nE 's|^location: .*/(nixos-[0-9.]+pre)[0-9]+\..*|\1|Ip')
candidates=()
while read -r release; do
  rev=$(curl -fsS "$releases/$release/git-revision")
  [[ $rev == "$locked_rev" ]] && break
  candidates+=("$rev")
  ((${#candidates[@]} < max_candidates)) || break
done < <(curl -fsS "https://nix-releases.s3.amazonaws.com/?list-type=2&prefix=nixos/unstable/$latest&delimiter=/" |
  grep -oE "${latest}[0-9]+\.[0-9a-f]+" | sed -E "s/^${latest}([0-9]+)\..*/\1 &/" | sort -urn | cut -d' ' -f2)

if ((${#candidates[@]} == 0)); then
  log "nixpkgs is already locked to the latest nixos-unstable release"
  exit 0
fi

# Computed on first use and kept for the rest of the run.
locked_closure() { # attr
  local file=$work/locked-closure-${1//[^A-Za-z0-9]/_}
  if [[ ! -f $file ]]; then
    nix-store -qR "$(nix eval --raw "$1.drvPath" 2>/dev/null)" | grep '\.drv$' | pnames >"$file"
  fi
  echo "$file"
}

# A closure can hold several variants of one package, such as an overridden
# nodejs beside the stock one. Building it locally only counts as a regression
# if the cache had every one of them.
was_cached() { # attr pname
  local drv out found=false
  while read -r drv; do
    found=true
    out=$(nix-store -q --outputs "$drv" | head -1)
    cached "$out" || return 1
  done < <(awk -v p="$2" '$1 == p { print $2 }' "$(locked_closure "$1")")
  $found
}

# Derivations with allowSubstitutes = false or preferLocalBuild, such as
# generated config files, always build locally.
drop_local_builds() {
  local drvs
  mapfile -t drvs
  ((${#drvs[@]} > 0)) || return 0
  nix derivation show "${drvs[@]}" 2>/dev/null | jq -r '
    (.derivations // .) | to_entries[]
    | (.value.structuredAttrs // .value.env) as $attrs
    | select(($attrs.allowSubstitutes // true) | IN(false, "") | not)
    | select(($attrs.preferLocalBuild // false) | IN(true, "1") | not)
    | .key | if startswith("/") then . else "/nix/store/" + . end'
}

check() { # rev
  local attr ok=true pkg drv
  for attr in "${attrs[@]}"; do
    if ! nix build --dry-run "$attr" --override-input nixpkgs "github:NixOS/nixpkgs/$1" \
      2>"$work/dry-run" >/dev/null; then
      log "  ✗ $attr doesn't evaluate:"
      { grep 'error:' "$work/dry-run" || true; } | tail -1 | sed -E 's/^ *(error: )?/    /' >&2
      return 1
    fi
    awk '/will be built:$/ { f = 1; next } !/^  / { f = 0 } f && /\.drv$/ { print $1 }' \
      "$work/dry-run" | drop_local_builds | pnames >"$work/to-build"
    while read -r pkg drv; do
      if was_cached "$attr" "$pkg"; then
        log "  ✗ $attr: $(basename "$drv" .drv | cut -c34-) isn't in cache.nixos.org"
        ok=false
      fi
    done <"$work/to-build"
    $ok || return 1
  done
}

for rev in "${candidates[@]}"; do
  log
  log "checking $rev"
  if check "$rev"; then
    log "  ✓ every host builds"
    nix flake lock --override-input nixpkgs "github:NixOS/nixpkgs/$rev"
    exit 0
  fi
done

log
log "none of the ${#candidates[@]} newest releases build on every host"
exit 1
