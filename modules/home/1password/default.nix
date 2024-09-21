{ lib, pkgs, ... }:
{
  config = {
    programs.git = lib.optionalAttrs pkgs.stdenv.isDarwin
      {
        extraConfig = {
          "gpg \"ssh\"".program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
        };
      };

    programs._1password-shell-plugins = {
      enable = true;

      plugins = with pkgs; [
        gh # github
        cargo
        heroku
        tea # gitea
        glab # gitlab
      ];
    };
  };
}
