{ lib, pkgs, config, ... }:
let
  _1pSocket = "/Users/${config.snowfallorg.user.name}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
in
{
  config = {
    programs.git = lib.optionalAttrs pkgs.stdenv.isDarwin
      {
        # extraConfig = {
        #   "gpg \"ssh\"".program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
        # };
      };


    programs.ssh = lib.optionalAttrs pkgs.stdenv.isDarwin {
      matchBlocks = {
        "*".extraOptions = {
          "IdentityAgent" = lib.strings.escapeShellArg _1pSocket;
        };
      };
    };

    home.sessionVariables = lib.optionalAttrs pkgs.stdenv.isDarwin {

      SSH_AUTH_SOCK = _1pSocket;
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
