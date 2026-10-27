# Claude Code's global rules, plus a `claude` that picks the install and signs
# in from agenix. Settings and CLAUDE.md stay as they are on each machine.
{
  config,
  inputs,
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

    # Home Manager gates plugin support on this. nixpkgs' version is the
    # oldest that can run, since the other installs only get newer.
    passthru.version = pkgs.claude-code.version;

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

  revdiffLauncher = ".claude-plugin/skills/revdiff/scripts/launch-revdiff.sh";
in
{
  home.packages = [ inputs.revdiff.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  programs.claude-code = {
    enable = true;
    package = claude;
    rulesDir = ./rules;

    plugins.revdiff = inputs.revdiff;

    # Merged into the writable settings.json at activation, so `/config` and
    # permission prompts can still write to it. A declared list replaces that
    # list in the file, though lists from other settings files still combine.
    mutableSettings = true;

    # Homebrew and Nix keep their copies current; the built-in updater would
    # reinstall through whichever npm is first in PATH (mise's). Anthropic's
    # installer does rely on it, so this needs revisiting if that's used.
    settings.env.DISABLE_AUTOUPDATER = "1";

    # Replaces the global allow list in settings.json on each switch, so a rule
    # added there by hand belongs here too. Project ones go in each project's
    # .claude/settings.local.json.
    settings.permissions.allow = [
      "mcp__context7__query-docs"
      "Bash(docker build *)"
      "Bash(docker compose *)"
      "Bash(jj diff *)"
      "Bash(jj log *)"
      "Bash(jj st *)"
      "Bash(jj squash *)"
    ];

    # Sandboxed `nix` commands need the daemon and their per-user cache and state
    settings.sandbox = {
      network.allowUnixSockets = [ "/nix/var/nix/daemon-socket/socket" ];
      filesystem = {
        allowRead = [
          "/nix/store"
          "~/.cache/nix"
          "~/.local/share/nix"
          "~/.nix-defexpr"
        ];
        allowWrite = [ "~/.cache/nix" ];
      };

      # revdiff's launcher drives Ghostty and iTerm2 with `osascript`, which
      # the sandbox blocks. The skill resolves the launcher through either the
      # plugin's link in skills/ or the store path it points to.
      excludedCommands = [
        "${inputs.revdiff}/${revdiffLauncher}*"
        "${config.programs.claude-code.configDir}/skills/revdiff/${revdiffLauncher}*"
      ];
    };
  };

  programs.zsh.profileExtra = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.mkAfter pathInit);
  programs.bash.profileExtra = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.mkAfter pathInit);
}
