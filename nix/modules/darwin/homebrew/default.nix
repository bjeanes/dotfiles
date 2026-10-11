{ pkgs, config, ... }: {
  config = {
    homebrew.enable = true;

    homebrew.taps = [
      "exoscale/tap"
      "terrastruct/tap"
    ];

    homebrew.brews = [
      "exoscale/tap/exoscale-cli"
      "terrastruct/tap/tala" # proprietary layout engine for D2
    ];
  };
}
