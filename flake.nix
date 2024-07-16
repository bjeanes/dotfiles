{
  inputs = {
    # Principle inputs (updated by `nix run .#update`)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:lnl7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-flake.url = "github:bjeanes/nixos-flake";

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
          mkNvim = system: inputs.nixvim.legacyPackages."${system}".makeNixvim {
            plugins.lsp.enable = true;
          };
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
              common = { pkgs, system, ... }:
                let
                  nvim = mkNvim system;
                in
                {
                  home-manager.backupFileExtension = "bak-hm";
                  home-manager.useUserPackages = true;
                  # home-manager.verbose = true;

                  nixpkgs.config.allowUnfree = true;

                  environment.variables = {
                    # EDITOR = "${nvim}/bin/nvim";
                    # VISUAL = "${nvim}/bin/nvim";
                  };

                  environment.systemPackages = with pkgs; [
                    git
                    bat
                  ];
                };

              # NixOS specific configuration
              linux = { pkgs, ... }: {
                users.users.${myUsername}.isNormalUser = true;
              };

              # nix-darwin specific configuration
              darwin = { pkgs, ... }: {
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
                programs.bash.enable = true;
                programs.zsh.enable = true;

                security.pam.enableSudoTouchIdAuth = true;
                users.users.${myUsername}.home = "/Users/${myUsername}";
              };
            };

            # All home-manager configurations are kept here; they are evaluated in the context of the user's home-manager profile.
            # i.e. `foo = true` is equivalent to `home-manager.users.bjeanes.foo = true`.
            homeModules = {
              # Common home-manager configuration shared between Linux and macOS.
              common = { pkgs, system, ... }:
                let
                  shellAliases = {
                    "g" = "git";
                    "l" = "ls";
                    "ll" = "ls -la";
                    "arst" = "asdf"; # Colemak home row
                  };
                in
                {
                  programs.git = {
                    enable = true;
                    aliases = {
                      c = "commit";
                      co = "checkout";
                      st = "status";
                    };
                  };
                  programs.starship.enable = true;
                  programs.bash.enable = true;
                  programs.bash.shellAliases = shellAliases;

                  programs.zsh = {
                    enable = true;
                    enableCompletion = true;
                    autocd = true;
                    syntaxHighlighting.enable = true;
                    autosuggestion.enable = true;
                    inherit shellAliases;
                  };

                  programs.direnv.enable = true;
                  programs.direnv.enableZshIntegration = true;
                  programs.direnv.enableBashIntegration = true;
                  programs.direnv.nix-direnv.enable = true;

                  home.packages = with pkgs; [
                    asdf
                  ];
                };

              # home-manager config specific to Linux / NixOS
              linux = { };

              # home-manager config specific to Darwin
              darwin = { };
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
