{ ... }:
{
  # h/t @khaneliman https://github.com/khaneliman/khanelinix/blob/7bf538d/modules/nixos/nix/default.nix#L13
  imports = [
    ../../shared/home
    ../../shared/nix
  ];
}
