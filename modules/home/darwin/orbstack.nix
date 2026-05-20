{
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (pkgs.stdenv.isDarwin) ({
    programs.ssh.includes = [
      "~/.orbstack/ssh/config"
    ];
  });
}
