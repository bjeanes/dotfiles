{ pkgs, ... }:
let
  user.name = "Bo Jeanes";
  user.email = "me@bjeanes.com";
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
      aliases = {
        br = "branch --format='%(color:red)%(committerdate:iso8601)%(color:reset) %(align:8)(%(ahead-behind:HEAD))%(end) %(color:blue)%(align:40)%(refname:short)%(end)%(color:reset) %(color:white)%(contents:subject) %(color:yellow)(%(committerdate:relative))%(color:reset)' --sort=-creatordate";
        oldestb = "br --sort=committerdate";
        newestb = "br --sort=-committerdate";

        c = "commit -v";
        co = "checkout";
        commit = "commit -v";
        lg = "log --decorate --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative";
        st = "status";
        unadd = "reset HEAD";

        me = "!sh -c 'echo `git config user.name` \\<`git config user.email`\\>'";
        mine = "!sh -c 'git lg --author=\"`git me`\"'";
      };

      extraConfig = {
        user = {
          inherit (user) name email;
        };

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

        status = {
          short = true;
          branch = true;
          showUntrackedFiles = "all";
        };

        commit.gpgsign = true;
        gpg.format = "ssh";
        user.signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJykg+5TulcwmeKFYSjZmnrL5/Fo4kWmOV1fAyt41Evh";
      };

      ignores = [
        "*.swp"
        ".DS_Store"
      ];
    };

    # difftastic will show syntactical/structural changes in diffs
    # programs.git.difftastic.enable = true;

    # delta will show diffs with language-aware syntax highlighting
    programs.git.delta.enable = true;
    programs.git.delta.package = pkgs.delta;
    programs.bash.initExtra = # bash
      ''
        eval "$(${pkgs.delta}/bin/delta --generate-completion bash)"
      '';
    programs.zsh.initExtra = # zsh
      ''
        eval "$(${pkgs.delta}/bin/delta --generate-completion zsh)"
      '';

    programs.lazygit.enable = true;
    programs.lazygit.settings = {
      # lazygit can pull the pager out of Git's config, but `programs.git.delta.enable = true` sets
      # the pager to `delta` directly, wheras `lazygit` requires `delta` to be called with
      # `--paging=never` due to rendering issues.
      #
      # https://github.com/jesseduffield/lazygit/blob/master/docs/Custom_Pagers.md
      git.paging.pager = "${pkgs.delta}/bin/delta --paging=never";

      update.method = "never"; # we will manage it here
      disableStartupPopups = true;

      os.editPreset = "nvim";
    };

    # TODO https://gist.github.com/ilyagr/5d6339fb7dac5e7ab06fe1561ec62d45 programs.jujutsu.enable = true;
    programs.jujutsu = {
      enable = true;
      settings = {
        inherit user;

        diff.tool = "delta";
        ui.pager = "delta";
        ui.diff.format = "git";
      };
    };

    home.packages = with pkgs; [
      gg-jj
      lazyjj
    ];
  };
}
