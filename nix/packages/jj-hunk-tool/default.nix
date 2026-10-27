# package.nix is from https://github.com/NixOS/nixpkgs/pull/573207, moved on
# to upstream's latest commit (it has no releases); drop this once jj-hunk-tool
# is in nixpkgs
{ pkgs, ... }:
(pkgs.callPackage ./package.nix { }).overrideAttrs (old: {
  # GNU patch, the usual `patch` on Linux and the one Nix puts first on macOS,
  # rejects some partial-hunk selections that `git apply` accepts:
  # https://github.com/mvzink/jj-hunk-tool/issues/2
  patches = old.patches or [ ] ++ [ ./git-apply.patch ];

  nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.makeWrapper ];
  postFixup = old.postFixup or "" + ''
    wrapProgram $out/bin/jj-hunk-tool --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.git ]}
  '';
})
