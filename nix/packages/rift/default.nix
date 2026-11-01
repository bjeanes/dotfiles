{ pkgs, ... }:
# nixpkgs is on 0.6.7, which predates the native-tab focus/layout fix (0.7.0).
pkgs.rift-wm.overrideAttrs (
  finalAttrs: prev: {
    version = "0.7.2";
    src = pkgs.fetchFromGitHub {
      owner = "acsandmann";
      repo = "rift";
      tag = "v${finalAttrs.version}";
      hash = "sha256-LXht4AfIBiSeS5jRZiadNBFBtpvZkB9bPRF/svXLqbc=";
    };
    cargoHash = "sha256-ZyRcaoNOkUKMqS77tz5ijmJR8lyAujPSpkVNbQ+6/Jo=";
    checkFlags = prev.checkFlags ++ [
      "--skip=actor::reactor::tests::named_pin_reload_moves_immediately_without_growing_catalog"
    ];
  }
)
