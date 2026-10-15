{ lib, pkgs, config, ... }:
let
  user.name = "Bo Jeanes";
  user.email = "me@bjeanes.com";

  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJykg+5TulcwmeKFYSjZmnrL5/Fo4kWmOV1fAyt41Evh";
in
{
  config = {
    programs.ssh = {
      matchBlocks = {
        "*" = {
          setEnv = {
            GIT_AUTHOR_NAME = user.name;
            GIT_AUTHOR_EMAIL = user.email;
          };
        };
      };
    };

    # TODO: https://nixos.asia/en/tips/git-profiles
    programs.git = {
      enable = true;

      settings = {
        alias = {
          br = "branch --format='%(color:red)%(committerdate:iso8601)%(color:reset) %(align:8)(%(ahead-behind:HEAD))%(end) %(color:blue)%(align:40)%(refname:short)%(end)%(color:reset) %(color:white)%(contents:subject) %(color:yellow)(%(committerdate:relative))%(color:reset)' --sort=-creatordate";
          oldestb = "br --sort=committerdate";
          newestb = "br --sort=-committerdate";

          c = "commit -v";
          co = "checkout";
          commit = "commit -v";
          lg = lib.concatStringsSep " " [
            "log --no-notes --decorate --graph"
            "--pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset'"
            "--abbrev-commit"
            "--date=relative"
            "--decorate-refs-exclude='refs/jj/keep/*'"
            "--exclude='refs/jj/keep/*'"
          ];
          st = "status";
          unadd = "reset HEAD";

          me = "!sh -c 'echo `git config user.name` \\<`git config user.email`\\>'";
          mine = "!sh -c 'git lg --author=\"`git me`\"'";
        };

        user = {
          inherit (user) name email;
        };

        rerere.enabled = true;

        apply.whitespace = "fix";

        init.defaultbranch = "main";

        color = {
          ui = "auto";
          branch = "auto";
          diff = "auto";
          status = "auto";
        };

        branch = {
          autosetupmerge = "always";
          autosetuprebase = "local";
        };

        push = {
          autosetupremote = true;
          default = "current";
          gpgSign = "if-asked";
        };

        rebase.autostash = true;
        pull.rebase = true;
        remote.pushDefault = "origin";

        remote.origin.fetch = "refs/notes/*:refs/notes/*";

        # Push notes alongside every push. Done as a hook rather than
        # `remote.origin.push`, because any configured push refspec replaces
        # `push.default = current` (and `push.autoSetupRemote`).
        hook.push-notes =
          let
            # pre-push hook: $1 = remote name, $2 = remote URL
            pushNotes = pkgs.writeShellScript "git-push-notes" ''
              cat >/dev/null # ref updates on stdin; unused
              git for-each-ref --count=1 --format=x refs/notes/ | grep -q . || exit 0
              git push --no-verify --quiet "$2" 'refs/notes/*:refs/notes/*' ||
                echo "warning: failed to push notes to $1 (fetch and \`git notes merge\` first?)" >&2
            '';
          in
          {
            event = "pre-push";
            command = "${pushNotes}";
          };

        notes = {
          # Show all notes refs (not just `refs/notes/commits`) in `git log`/`git show`
          displayRef = "refs/notes/*";
          # Carry notes over to the new commits on `rebase` and `commit --amend`
          rewriteRef = "refs/notes/*";
        };

        status = {
          short = true;
          branch = true;
          showUntrackedFiles = "all";
        };

        commit.gpgsign = true;
        user.signingkey = signingKey;
      };

      signing.format = "ssh";

      ignores = [
        "*.swp"
        ".DS_Store"
      ];
    };

    # difftastic will show diffs with language-aware _structural_ syntax highlighting
    programs.difftastic = {
      enable = true;
      jujutsu.enable = true;
      git.enable = true;
    };

    programs.lazygit.enable = true;
    programs.lazygit.settings = {
      # lazygit can pull the pager out of Git's config, but `programs.git.difftastic.enable = true` sets
      # the pager to `difftastic` directly, wheras `lazygit` requires `difftastic` to be called with
      # `--paging=never` due to rendering issues.
      #
      # https://github.com/jesseduffield/lazygit/blob/master/docs/Custom_Pagers.md
      git.pagers = [
        { pager = "${pkgs.delta}/bin/delta --dark --paging=never"; }
        { externalDiffCommand = "${pkgs.difftastic}/bin/difft --color=always --display=inline"; }
      ];

      autoFetch = false;
      update.method = "never"; # we will manage it here
      disableStartupPopups = true;

      os.editPreset = "nvim";
    };

    home.activation.local-jj = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      local_config_dir="${config.xdg.configHome}/jj/conf.d"
      mkdir -p "$local_config_dir"
      local_config_file="$local_config_dir/local.toml"
      if [ ! -f "$local_config_file" ]; then
        cp ${./jj.local.toml} "$local_config_file"
        chmod 755 "$local_config_file"
      fi
    '';

    programs.jujutsu = {
      enable = true;

      # https://github.com/jj-vcs/jj/blob/main/docs/config.md
      settings = {
        inherit user;

        signing = {
          behavior = "own";
          backend = "ssh";
          key = signingKey;
        };

        template-aliases = {
          # Relative timestamp rendered as "x days/hours/seconds ago"
          "format_timestamp(timestamp)" = "timestamp.ago()";

          "format_short_signature(signature)" = ''
            if(
              signature.email().domain() == "users.noreply.github.com",
              signature.email().local().replace(regex:"^[0-9]+\\+", "") ++ "@GH",
              if(
                signature.email().local() == "me" ||
                  signature.email().local() == "hello" ||
                  signature.email().local() == "dev" ||
                  signature.email().local() == "git",
                signature.email().domain(),
                signature.email().local() ++ "@"
              )
            )
          '';

          # https://ddbeck.com/notes/jj-git-push-bookmark-template/
          "slugify(str)" = ''
            truncate_end(
              65,
              str.first_line()
                .replace(regex:"[^[[:alnum:]].]", "-")
                .replace(regex:"-{2,}", "-")
                .replace(regex:"\\.{2,}", ".")
                .replace(regex:"(^-+|-+$)", "")
                .lower()
            )
          '';

          # Builtin labels, plus a locked-with-key on mutable commits matching
          # `private()` and a plain lock on their descendants (unpushable while
          # they have a private ancestor). Only mutable commits are considered,
          # as evaluating `private()` (esp. `empty()`) over all history is slow.
          "format_commit_labels(commit)" = ''
            separate(" ",
              coalesce(
                if(commit.hidden(), label("hidden", "(hidden)")),
                if(commit.divergent(), label("divergent", "(divergent)")),
              ),
              if(commit.conflict(), label("conflict", "(conflict)")),
              coalesce(
                if(commit.contained_in("mutable() & private()"), "🔐"),
                if(commit.contained_in("(mutable() & private())::"), "🔒"),
              ),
            )
          '';
        };

        templates = {
          git_push_bookmark = ''
            "bjeanes/" ++ change_id.short() ++ "-" ++ slugify(description)
          '';
        };

        remotes.origin.auto-track-bookmarks = "bjeanes/*";

        git.sign-on-push = true;

        # See `private()` revset alias
        git.private-commits = "private()";

        ui.default-command = "log";

        revset-aliases = {
          # https://isaaccorbrey.com/notes/jujutsu-megamerges-for-fun-and-profit
          "closest_merge(to)" = "heads(::to & merges())";

          # Commits that others depend on, so shouldn't be rewritten (e.g. by
          # `jj restack`). Set per-repo with `jj pin`; unpin with
          # `jj config edit --repo`.
          "pinned()" = "none()";
          "immutable_heads()" = "builtin_immutable_heads() | pinned()";

          # Any commit matching any of these revset expressions will be treated
          # as "private" and will not be pushable (without `--allow-private`)
          #
          # commits with empty messages are already blocked for pushing (without
          # `--allow-empty-description`) so no need to specify that here.
          "private()" = lib.concatMapStringsSep " | " (t: "( ${t} )") (
            # Any commit with one of these subjects, either as a prefix or whole line
            lib.concatMap
              (w: [
                "subject(exact-i:'${w}')"
                "subject(glob-i:'${w}:*')"
              ])
              [
                "wip"
                "prv"
                "priv"
                "private"
              ]
            ++ [
              # commits with conflicts
              "conflicts()"

              # empty commits, except root commit and merges
              "empty() ~ (root() | merges())"

              # per-repo additions, via `jj config edit --repo`
              "local_private()"
            ]
          );
          "local_private()" = "none()";
        };

        # Default log, plus every local bookmark's commits back to trunk, including
        # immutable ones (e.g. `pinned()`). Deliberately avoids mentioning remote
        # bookmarks: doing so makes stale (hidden) remote targets visible.
        revsets.log = "builtin_log() | (trunk()..bookmarks())";

        aliases = {
          # https://jj-vcs.github.io/jj/latest/FAQ/#can-i-monitor-how-jj-log-evolves
          mon = [
            "util"
            "exec"
            "--"
            "sh"
            "-c"
            "clear; jj --ignore-working-copy --no-pager --color always log; fswatch -o  `jj root`/.jj | xargs -I{} sh -c 'clear; jj --ignore-working-copy --no-pager --color always log'"
          ];

          # https://isaaccorbrey.com/notes/jujutsu-megamerges-for-fun-and-profit
          #
          # Incorporate a revset which is a descendent of a megamerge into the
          # megamerge (between latest trunk and megamerge). Takes multiple
          # arguments, each one being an independent (parallel) stack under the
          # megamerge.
          stack = [
            "rebase"
            "--after"
            "trunk()"
            "--before"
            "closest_merge(@)"
            "--revisions"
          ];

          # https://isaaccorbrey.com/notes/jujutsu-megamerges-for-fun-and-profit
          #
          # Incorporate all commits after the megamerge as a single patch-series
          # under the megamerge (on top of latest trunk). Like `stack` above,
          # except it requires no arguments and treats everything as a single stack
          stage = [
            "stack"
            "closest_merge(@)+:: ~ empty()"
          ];

          # https://isaaccorbrey.com/notes/jujutsu-megamerges-for-fun-and-profit
          #
          # Easier bulk rebasing of WIP (between previous trunk and megamerge) onto latest trunk
          restack = [
            "rebase"
            "--onto"
            "trunk()"
            "--source"
            "roots(trunk()..) & mutable()"
            "--simplify-parents"
            "--skip-emptied"
          ];

          # Append revsets to this repo's `pinned()` (making them immutable).
          # Pin a remote bookmark (e.g. `jj pin my-feature@origin`) so it
          # follows the branch if others push to it.
          pin =
            let
              # `jj pin <revset>...`: append revsets to this repo's `pinned()` alias
              jjPin = pkgs.writeShellScript "jj-pin" /* bash */ ''
                set -eu
                [ $# -gt 0 ] || { echo "usage: jj pin <revset>..." >&2; exit 1; }
                key='revset-aliases."pinned()"'
                pins=$(jj config get "$key" 2>/dev/null || echo 'none()')
                for rev in "$@"; do
                  jj log --ignore-working-copy --no-graph -r "$rev" -T commit_id >/dev/null
                  if [ "$pins" = 'none()' ]; then pins="($rev)"; else pins="$pins | ($rev)"; fi
                done
                jj config set --repo "$key" "$pins"
                echo "pinned() = $pins"
              '';
            in
            [
              "util"
              "exec"
              "--"
              "${jjPin}"
            ];

          # When editing an earlier commit, `jj git push` won't push later
          # rebased commits because:
          #
          #     Warning: No bookmarks found in the default push revset: remote_bookmarks(remote=origin)..@
          #
          # This provides a different revset that doesn't is open ended (`..` vs
          # `..@`) which will push all sideways bookmarks, regardless of current
          # working commit.
          gpa = [
            "git"
            "push"
            "-r"
            "remote_bookmarks(remote=origin).." # default would end in `..@`
          ];
        };

      };
    };

    programs.bash.initExtra = /* bash */ ''
      source <(COMPLETE=bash jj)
    '';

    programs.zsh.initContent = /* zsh */ ''
      source <(COMPLETE=zsh jj)
    '';

    home.packages = with pkgs; [
      gg-jj
    ];
  };
}
