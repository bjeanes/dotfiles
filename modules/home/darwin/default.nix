{
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (pkgs.stdenv.isDarwin) (
    let
      init = ''
        . ${./watch-defaults.sh}
        [ -d /opt/homebrew/bin ] && eval "$(/opt/homebrew/bin/brew shellenv)"
      '';
    in
    {
      programs.zsh.initContent = init;
      programs.bash.initExtra = init;
    }
  );
}
