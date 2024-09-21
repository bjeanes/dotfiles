{ lib, ... }: {
  # h/t @khaneliman https://github.com/khaneliman/khanelinix/blob/7bf538d/modules/nixos/nix/default.nix#L13
  imports = [ (lib.snowfall.fs.get-file "modules/shared/nix/default.nix") ];

  config = {
    nix.gc.dates = "weekly";
  };
}
