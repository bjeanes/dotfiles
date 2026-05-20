{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./orbstack.nix
    ./homebrew.nix
  ];

  config = lib.mkIf (pkgs.stdenv.isDarwin) (
    let
      init = ''
        . ${./watch-defaults.sh}
      '';
    in
    {
      programs.zsh.initContent = init;
      programs.bash.initExtra = init;
    }
  );
}
