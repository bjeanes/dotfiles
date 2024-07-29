{
  inputs = {
    # Principle inputs (updated by `nix run .#update`)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:lnl7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-flake.url = "github:srid/nixos-flake";

    # Neovim
    nixvim = {
      url = "github:nix-community/nixvim";

      # nixvim has a lot of inputs we are using, so pin them to same version
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nix-darwin.follows = "nix-darwin";
        home-manager.follows = "home-manager";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # https://developer.1password.com/docs/cli/shell-plugins/nix/
    _1password-shell-plugins = {
      url = "github:1Password/shell-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "nixvim/devshell/flake-utils";
    };

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    nil = {
      url = "github:oxalica/nil";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "nixvim/devshell/flake-utils";
    };
  };

  outputs = inputs@{ self, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
      (
        let
          myUsername = "bjeanes";
        in
        {
          systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

          imports = [
            inputs.nixos-flake.flakeModule
            inputs.treefmt-nix.flakeModule
          ];

          # flake-parts will export this wholesale as the flakes' `outputs`, with no per-system transposition. See `perSystem` below for this.
          flake = {
            # Configurations for Linux (NixOS) machines
            nixosConfigurations = { };

            # Configurations for macOS machines
            darwinConfigurations = {
              # Work M3 Max MBP
              Jabberwocky = self.darwinConfigurations.Bandersnatch;

              # Personal M1 Max MBP
              Bandersnatch = self.nixos-flake.lib.mkMacosSystem {
                nixpkgs.hostPlatform = "aarch64-darwin";
                imports = [
                  self.nixosModules.common # See below for "nixosModules"!
                  self.nixosModules.darwin

                  # Your machine's configuration.nix goes here
                  ({ pkgs, ... }: {
                    # Used for backwards compatibility, please read the changelog before changing.
                    # $ darwin-rebuild changelog
                    system.stateVersion = 4;
                  })

                  # Your home-manager configuration
                  self.darwinModules_.home-manager
                  {
                    home-manager.users.${myUsername} = {
                      imports = [
                        self.homeModules.common # See below for "homeModules"!
                        self.homeModules.darwin
                      ];
                      home.stateVersion = "24.05";
                    };
                  }
                ];
              };
            };

            # All nixos/nix-darwin configurations are kept here.
            nixosModules = {
              # Common nixos/nix-darwin configuration shared between Linux and macOS.
              common = { pkgs, ... }:
                {
                  home-manager.backupFileExtension = "bak-hm";
                  home-manager.useUserPackages = true;
                  # home-manager.verbose = true;

                  nixpkgs.config.allowUnfree = true;

                  environment.variables = { };

                  environment.systemPackages = with pkgs; [
                    git
                    bat

                    # In system packages so VSCode more reliably finds these
                    direnv
                    nil
                    nixpkgs-fmt
                  ];
                };

              # NixOS specific configuration
              linux = { pkgs, ... }: {
                imports = [
                  inputs.nixvim.nixosModules.nixvim
                ];

                users.users.${myUsername}.isNormalUser = true;
              };

              # nix-darwin specific configuration
              darwin = { pkgs, ... }: {
                imports = [
                  inputs.nixvim.nixDarwinModules.nixvim
                ];

                nix.useDaemon = true;
                services.nix-daemon.enable = true;
                services.nix-daemon.enableSocketListener = true;

                nix = {
                  configureBuildUsers = true;

                  ## Control the version of Nix that nix-darwin uses. At time of writing, it defaults to 2.18.x, but latest is 2.23.3.
                  ## Commented out because versions after 2.18.x are apparently pretty buggy
                  # package = pkgs.nixVersions.latest;

                  # Use Lix (a Nix-compatible lang -- https://lix.systems)
                  package = pkgs.lix;

                  settings = {
                    trusted-users = [ "root" myUsername ];
                    allowed-users = [ "root" myUsername "@nixbld" ];

                    auto-optimise-store = true; # https://daiderd.com/nix-darwin/manual/index.html#opt-nix.settings.auto-optimise-store
                  };

                  extraOptions = ''
                    extra-nix-path = "nixpkgs=flake:nixpkgs"
                    experimental-features = nix-command flakes
                  '';
                };

                homebrew.enable = true;
                homebrew.taps = [
                  "exoscale/tap"
                  "terrastruct/tap"
                ];

                homebrew.brews = [
                  "exoscale/tap/exoscale-cli"
                  "terrastruct/tap/tala" # proprietary layout engine for D2
                ];

                # This needs to be here in addition to the home-manager configuration below in order to write /etc/zshenv to correctly configure ZSH. This is confusing, but...
                # https://github.com/LnL7/nix-darwin/issues/1003
                # https://github.com/LnL7/nix-darwin/issues/922#issuecomment-2041430035
                programs.zsh.enable = true;
                programs.bash.enable = true;

                security.pam.enableSudoTouchIdAuth = true;
                users.users.${myUsername}.home = "/Users/${myUsername}";

                system.keyboard.enableKeyMapping = true;
                system.keyboard.remapCapsLockToControl = true;
              };
            };

            # All home-manager configurations are kept here; they are evaluated in the context of the user's home-manager profile.
            # i.e. `foo = true` is equivalent to `home-manager.users.bjeanes.foo = true`.
            homeModules = {
              # Common home-manager configuration shared between Linux and macOS.
              common = { pkgs, ... }:
                let
                  code-font = "MesloLGMDZ Nerd Font Mono";
                  nerdfonts = (pkgs.nerdfonts.override {
                    fonts = [
                      "BitstreamVeraSansMono"
                      "Meslo"
                      "SourceCodePro"
                      "Monaspace" # Monaspace Argon, specifically
                      "FiraCode"
                    ];
                  });
                in
                {
                  imports = [
                    inputs.nixvim.homeManagerModules.nixvim
                    inputs._1password-shell-plugins.hmModules.default
                  ];

                  home.shellAliases = {
                    g = "git";
                    l = "ls";
                    ll = "ls -la";
                    arst = "asdf"; # Colemak home row
                    cat = "bat";
                    lg = "lazygit";
                    cd = "z";
                  };

                  programs.nixvim = {
                    enable = true;
                    defaultEditor = true;

                    viAlias = true;
                    vimAlias = true;
                  };

                  programs.git = {
                    enable = true;
                    aliases = {
                      br = "branch";
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

                      rebase.autostash = true;
                      pull.rebase = true;
                      push.default = "current";
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
                    ];
                  };

                  # difftastic will show syntactical/structural changes in diffs
                  # programs.git.difftastic.enable = true;

                  # delta will show diffs with language-aware syntax highlighting
                  programs.git.delta.enable = true;
                  programs.git.delta.package = pkgs.delta;
                  programs.bash.initExtra = /* bash */ ''
                    eval "$(${pkgs.delta}/bin/delta --generate-completion bash)"
                  '';
                  programs.zsh.initExtra = /* zsh */ ''
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

                  programs.gh.enable = true;
                  programs.gh.settings.aliases = {
                    # https://cli.github.com/manual/gh_alias_set
                    configure-repo-squash = "api repos/{owner}/{repo} --method PATCH -f allow_squash_merge=true -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY";
                    configure-repo-delete-merged = "api repos/{owner}/{repo} --method PATCH -f delete_branch_on_merge=true";
                    configure-repo = "!gh configure-repo-squash && gh configure-repo-delete-merged";
                  };

                  programs.zsh = {
                    enable = true;
                    enableCompletion = true;
                    autocd = true;
                    syntaxHighlighting.enable = true;
                    autosuggestion.enable = true;
                  };
                  programs.bash = {
                    enable = true;
                    enableCompletion = true;
                    enableVteIntegration = true;
                  };
                  programs.starship.enable = true;

                  programs.direnv.enable = true;
                  programs.direnv.enableZshIntegration = true;
                  programs.direnv.enableBashIntegration = true;
                  programs.direnv.nix-direnv.enable = true;

                  programs.bat.enable = true;
                  programs.bat.config = {
                    map-syntax = [
                      "flake.lock:JSON"
                    ];
                  };

                  # By default, this integration also hooks into shell ^R for history search, but atuin is better
                  # and fortunately appears to take precedence when both are enabled
                  programs.fzf.enable = true;
                  programs.fzf.enableZshIntegration = true;
                  programs.fzf.enableBashIntegration = true;
                  programs.fzf.fileWidgetOptions = [
                    "--preview '${pkgs.bat}/bin/bat --color=always --style=numbers --line-range :500 {}'"
                  ];


                  # Shell history recording + UI
                  programs.atuin.enable = true;
                  programs.atuin.enableZshIntegration = true;
                  programs.atuin.enableBashIntegration = true;
                  programs.atuin.settings = {
                    dialect = "uk";
                    filter_mode_shell_up_key_binding = "session";
                    workspaces = true;
                    style = "compact";
                    inline_height = 20;
                    enter_accept = false;
                    ctrl_n_shortcuts = true;

                    stats.common_prefix = [
                      "sudo"
                      "time"
                    ];
                  };

                  programs.zoxide = {
                    enable = true;
                    enableBashIntegration = true;
                    enableZshIntegration = true;
                  };

                  programs.eza = {
                    enable = true;
                    git = true;
                    icons = true;
                    enableBashIntegration = true;
                    enableZshIntegration = true;
                  };

                  programs.kitty = {
                    enable = true;
                    extraConfig = ''
                      background_opacity 0.8
                      background_blur 10
                      enable_audio_bell no
                    '';
                    theme = "Tomorrow Night Eighties";
                    font = {
                      package = nerdfonts;
                      name = code-font;
                      size = 13;
                    };
                  };

                  # TODO: https://news.ycombinator.com/item?id=31010090 for wiring together `rg`+`fzf`+`bat`
                  programs.ripgrep.enable = true;

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

                  fonts.fontconfig.enable = true;
                  fonts.fontconfig.defaultFonts.monospace = [
                    code-font
                  ];

                  home.packages = with pkgs; [
                    nerdfonts

                    # TODO: https://gist.github.com/axelbdt/0de9f5f9ba8a2100326b793f7bfb8658?permalink_comment_id=4977667#gistcomment-4977667
                    asdf-vm

                    git-absorb # https://github.com/tummychow/git-absorb
                    mkcert

                    # d2 # does not include proprietary Tala layout engine, and installing it with brew auto-installs brew's version of d2
                  ];
                };

              # home-manager config specific to Linux / NixOS
              linux = { };

              # home-manager config specific to Darwin
              darwin = { pkgs, ... }: {
                # Yank/paste in Neovim to/from macOS clipboard by default
                programs.nixvim.clipboard.register = "unnamedplus";

                programs.git.extraConfig."gpg \"ssh\"".program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";

                home.sessionVariables =
                  let
                    brewPrefix =
                      if pkgs.stdenv.hostPlatform.isAarch64
                      then "/opt/homebrew"
                      else "/usr/local";
                  in
                  {
                    PATH = "${brewPrefix}/bin:${brewPrefix}/sbin:$PATH";
                  };
              };
            };
          };

          perSystem = { self', inputs', pkgs, system, config, ... }: {
            # Non-NixOS Linux machine TumTum
            legacyPackages.homeConfigurations."${myUsername}@tumtum" =
              self.nixos-flake.lib.mkHomeConfiguration pkgs {
                imports = [
                  self.homeModules.common
                  self.homeModules.linux
                ];
              };

            # Make `nix run` equivalent to `nix run .#activate`
            packages.default = self'.packages.activate;

            treefmt.config = {
              projectRootFile = "flake.lock";
              programs.nixpkgs-fmt.enable = true;
              programs.nixpkgs-fmt.package = pkgs.nixpkgs-fmt;
            };

            devShells.default = pkgs.mkShell {
              nativeBuildInputs = with pkgs; [
                inputs.nil.packages.${system}.nil
                nixpkgs-fmt
              ];
            };
          };
        }
      );
}
