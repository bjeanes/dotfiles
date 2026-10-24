# Claude Code's global rules, plus a `claude` that picks the install and signs
# in from agenix. Settings and CLAUDE.md stay as they are on each machine.
{
  lib,
  pkgs,
  ...
}:
let
  # The newest install there is: Anthropic's own installer (it updates itself),
  # then Homebrew's, then nixpkgs' as the baseline. The token is a long-lived
  # one from `claude setup-token`, kept in agenix, so each machine needn't log
  # in separately. It is used wherever it is readable (a recipient that owns
  # it); elsewhere this is plain `claude` with its usual login.
  claude = pkgs.writeShellApplication {
    name = "claude";
    text = ''
      real=${lib.getExe pkgs.claude-code}
      for installed in "$HOME/.local/bin/claude" /opt/homebrew/bin/claude /usr/local/bin/claude; do
        if [[ -x $installed ]]; then
          real=$installed
          break
        fi
      done

      # Set at all, even empty, leaves it alone: `CLAUDE_CODE_OAUTH_TOKEN= claude`
      # runs on the regular login
      token=/run/agenix/claude-code-oauth-token
      if [[ ! -v CLAUDE_CODE_OAUTH_TOKEN && -r $token ]]; then
        CLAUDE_CODE_OAUTH_TOKEN=$(tr -d '\r\n' <"$token")
        export CLAUDE_CODE_OAUTH_TOKEN
      fi

      exec "$real" "$@"
    '';
  };

  # Ahead of Homebrew's own bin, which `brew shellenv` puts first
  pathInit = ''
    export PATH="${claude}/bin:$PATH"
  '';
in
{
  programs.claude-code = {
    enable = true;
    package = claude;
    rulesDir = ./rules;
  };

  programs.zsh.profileExtra = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.mkAfter pathInit);
  programs.bash.profileExtra = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.mkAfter pathInit);
}
