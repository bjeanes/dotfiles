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

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
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

                nix = {
                  useDaemon = true;

                  ## Control the version of Nix that nix-darwin uses. At time of writing, it defaults to 2.18.x, but latest is 2.23.3.
                  ## Commented out because versions after 2.18.x are apparently pretty buggy
                  # package = pkgs.nixVersions.latest;

                  # Use Lix (a Nix-compatible lang -- https://lix.systems)
                  package = pkgs.lix;

                  settings = {
                    trusted-users = [ "root" myUsername ];
                    allowed-users = [ "root" myUsername "@nixbld" ];
                  };

                  extraOptions = ''
                    extra-nix-path = "nixpkgs=flake:nixpkgs"
                    experimental-features = nix-command flakes
                  '';
                };

                homebrew.enable = true;

                # This needs to be here in addition to the home-manager configuration below in order to write /etc/zshenv to correctly configure ZSH. This is confusing, but...
                # https://github.com/LnL7/nix-darwin/issues/1003
                # https://github.com/LnL7/nix-darwin/issues/922#issuecomment-2041430035
                programs.zsh.enable = true;
                programs.bash.enable = true;

                security.pam.enableSudoTouchIdAuth = true;
                users.users.${myUsername}.home = "/Users/${myUsername}";
              };
            };

            # All home-manager configurations are kept here; they are evaluated in the context of the user's home-manager profile.
            # i.e. `foo = true` is equivalent to `home-manager.users.bjeanes.foo = true`.
            homeModules = {
              # Common home-manager configuration shared between Linux and macOS.
              common = { pkgs, ... }:
                {
                  imports = [
                    inputs.nixvim.homeManagerModules.nixvim
                  ];

                  home.shellAliases = {
                    g = "git";
                    l = "ls";
                    ll = "ls -la";
                    arst = "asdf"; # Colemak home row
                    cat = "bat";
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

                      pull.rebase = true;
                      push.default = "current";
                      remote.pushDefault = "origin";

                      status = {
                        short = true;
                        branch = true;
                        showUntrackedFiles = "all";
                      };
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

                  programs.fzf.enable = true;
                  programs.fzf.enableZshIntegration = true;
                  programs.fzf.enableBashIntegration = true;
                  programs.fzf.fileWidgetOptions = [
                    "--preview '${pkgs.bat}/bin/bat --color=always --style=numbers --line-range :500 {}'"
                  ];

                  home.packages = with pkgs; [
                    asdf
                  ];
                };

              # home-manager config specific to Linux / NixOS
              linux = { };

              # home-manager config specific to Darwin
              darwin = {
                # Yank/paste in Neovim to/from macOS clipboard by default
                programs.nixvim.clipboard.register = "unnamedplus";
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
            };
          };
        }
      );
}
