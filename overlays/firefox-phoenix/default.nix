# This overlays purpose is to provide a wrapper around Firefox such that it is configured for maximum privacy, according
# to the set of Policies, Settings, and Add-ons as specified by the Phoenix project.
#
# https://codeberg.org/celenity/Phoenix
# https://github.com/NixOS/nixpkgs/blob/2a3a53a2fe8ae563c3c3c4d39c189ebc31acc308/pkgs/applications/networking/browsers/firefox/wrapper.nix#L51
{ inputs, ... }: final: prev:
let
  phoenix = inputs.phoenix;

  applyPhoenix = (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
      final.findutils
    ];
    postInstall = ''
      dest="$(find "$out" -name application.ini -exec dirname {} \; | head -n 1)"
      mkdir -p "$dest"/defaults/pref "$dest"/distribution

      ln -s ${phoenix}/mozilla.cfg "$dest"/
      ln -s ${phoenix}/defaults/pref/local-settings.js "$dest"/defaults/pref/
      ln -s ${phoenix}/policies/Policies/policies.json "$dest"/distribution/
    '';
  });
in
{
  firefox-bin = prev.firefox-bin.overrideAttrs applyPhoenix;
}
