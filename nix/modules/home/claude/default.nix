# Claude Code's global rules, plus a `claude` that picks the install and signs
# in from agenix. Settings and CLAUDE.md stay as they are on each machine.
{
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

  revdiffLauncher = "${inputs.revdiff}/.claude-plugin/skills/revdiff/scripts/launch-revdiff.sh";

  jjReview = pkgs.runCommandLocal "jj-review-skill" { } ''
    cp -r ${./skills/jj-review} $out
    chmod -R u+w $out
    patchShebangs $out/scripts
    substituteInPlace $out/scripts/jj-review-loop.sh --replace-fail @launcher@ ${revdiffLauncher}
    substituteInPlace $out/SKILL.md --replace-fail @out@ $out
  '';

  writingReview = pkgs.writeShellApplication {
    name = "writing-review";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      jq
    ];
    text = builtins.readFile ./hooks/writing-review.sh;
  };

  commentReview = pkgs.writeShellApplication {
    name = "comment-review";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      jq
    ];
    text = builtins.readFile ./hooks/comment-review.sh;
  };

  # A hook's `if` holds a single permission rule, so each command needs its own
  writingCommands = [
    "jj describe"
    "jj desc"
    "jj commit"
    "jj split"
    "jj new"
    "gh pr create"
    "gh pr edit"
    "gh pr comment"
    "gh pr review"
    "gh api"
  ];
in
{
  home.packages = [ inputs.revdiff.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  programs.claude-code = {
    enable = true;
    package = claude;
    rulesDir = ./rules;

    # Through a marketplace, since `plugins` links the plugin in as a symlink.
    # revdiff's manifest names its skills directory, which then resolves into
    # the store, outside the link, and Claude Code skips it.
    marketplaces.revdiff = inputs.revdiff;
    settings.enabledPlugins."revdiff@revdiff" = true;

    skills.jj-review = jjReview;
    skills.write-as-me = ./skills/write-as-me;

    agents.writing-reviewer = ./agents/writing-reviewer.md;

    # Rules loaded at the start of a session lose their pull as it grows, so
    # bring the writing rules back just before text goes out under my name.
    # Declaring PreToolUse replaces any PreToolUse list added to settings.json
    # by hand.
    settings.hooks.PreToolUse = [
      {
        matcher = "Bash";
        hooks = map (command: {
          type = "command";
          "if" = "Bash(${command} *)";
          command = lib.getExe writingReview;
        }) writingCommands;
      }
    ];

    # After the edit, since fixing a comment is just another edit. Declaring
    # PostToolUse likewise replaces a list added to settings.json by hand.
    settings.hooks.PostToolUse = [
      {
        matcher = "Edit|MultiEdit|Write";
        hooks = [
          {
            type = "command";
            command = lib.getExe commentReview;
          }
        ];
      }
    ];

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
      "Skill(jj-review)"
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

      # revdiff's launcher opens its overlay through tmux's socket, or through
      # `osascript` for Ghostty and iTerm2, all of which the sandbox blocks.
      # jj-review's loop runs the launcher for each change.
      excludedCommands = [
        "${revdiffLauncher}*"
        "${jjReview}/scripts/jj-review-loop.sh*"
      ];
    };
  };

  programs.zsh.profileExtra = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.mkAfter pathInit);
  programs.bash.profileExtra = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.mkAfter pathInit);
}
