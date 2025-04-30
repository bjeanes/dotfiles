{
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (pkgs.stdenv.isDarwin) {
    programs.zsh.initContent = ". ${./watch-defaults.sh}";
    programs.bash.initExtra = ". ${./watch-defaults.sh}";
  };
}
