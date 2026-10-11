{
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin) (
    let
      init = ''
        source ~/.orbstack/shell/init.zsh 2>/dev/null || :
      '';
    in
    {
      programs.zsh.profileExtra = init;
      programs.bash.profileExtra = init;

      programs.ssh.includes = [
        "~/.orbstack/ssh/config"
      ];
    }
  );
}
