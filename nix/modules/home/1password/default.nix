{
  lib,
  pkgs,
  config,
  ...
}:
let
  _1pSocket = "/Users/${config.home.username}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
in
{
  config = {
    programs.ssh = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
      # Inside an SSH session, defer to the forwarded agent in $SSH_AUTH_SOCK
      settings._1password-agent = {
        header = ''Match !exec "test -n \"$SSH_CONNECTION\""'';
        IdentityAgent = lib.strings.escapeShellArg _1pSocket;
      };
    };

    home.sessionVariablesExtra = lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      if [ -z "$SSH_CONNECTION" ]; then
        export SSH_AUTH_SOCK=${lib.strings.escapeShellArg _1pSocket}
      fi
    '';

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
