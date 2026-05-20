{
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (pkgs.stdenv.isDarwin) (
    let
      init = ''
        [ -d /opt/homebrew/bin ] && eval "$(/opt/homebrew/bin/brew shellenv)"
      '';
    in
    {
      programs.zsh.profileExtra = init;
      programs.bash.profileExtra = init;
    }
  );
}
