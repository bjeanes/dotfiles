{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/release-2.91.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "snowfall-lib/flake-utils-plus/flake-utils";
    };

    mise = {
      url = "github:jdx/mise";

      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "snowfall-lib/flake-utils-plus/flake-utils";
      };
    };

    catppuccin.url = "github:catppuccin/nix";

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    snowfall-flake = {
      url = "github:snowfallorg/flake";
      # Flake requires some packages that aren't on 22.05, but are available on unstable.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";

      # nixvim has a lot of inputs we are using, so pin them to same version
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nix-darwin.follows = "darwin";
        home-manager.follows = "home-manager";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        flake-compat.follows = "snowfall-lib/flake-compat";
      };
    };

    khanelivim = {
      url = "github:khaneliman/khanelivim";
      inputs.snowfall-lib.follows = "snowfall-lib";
      inputs.snowfall-flake.follows = "snowfall-flake";
      inputs.nixvim.follows = "nixvim";
    };

    # https://developer.1password.com/docs/cli/shell-plugins/nix/
    _1password-shell-plugins = {
      url = "github:1Password/shell-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "snowfall-lib/flake-utils-plus/flake-utils";
    };

    nixpkgs-firefox-darwin.url = "github:bandithedoge/nixpkgs-firefox-darwin";
    nixpkgs-firefox-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # nix-index-database.url = "github:nix-community/nix-index-database";
    # nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    phoenix = {
      url = "git+https://codeberg.org/celenity/Phoenix.git?shallow=1";
      flake = false;
    };

    nil = {
      url = "github:oxalica/nil";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "snowfall-lib/flake-utils-plus/flake-utils";
    };

    zsh-cd-ls = {
      url = "github:zshzoo/cd-ls";
      flake = false;
    };

    zsh-autopair = {
      url = "github:hlissner/zsh-autopair";
      flake = false;
    };
  };

  outputs =
    inputs:
    (inputs.snowfall-lib.mkFlake {
      inherit inputs;
      src = ./.;

      channels-config = {
        allowUnfree = true;
      };

      overlays = with inputs; [
        darwin.overlays.default
        snowfall-flake.overlays.default
        nixpkgs-firefox-darwin.overlay
        lix-module.overlays.default
      ];

      systems.modules.darwin = [ ];

      systems.modules.nixos = with inputs; [
        catppuccin.nixosModules.catppuccin
      ];

      homes.modules = with inputs; [
        _1password-shell-plugins.hmModules.default
        catppuccin.homeManagerModules.catppuccin
      ];

      alias = {
        packages.default = "switch";
      };

      outputs-builder = channels:
        # let
        #   system = channels.nixpkgs.system;
        #   treefmtEval = inputs.treefmt-nix.lib.evalModule channels.nixpkgs ./treefmt.nix;
        # in
        {

          formatter = channels.nixpkgs.nixpkgs-fmt;
          # formatter = treefmtEval.${system}.config.build.wrapper;
          # checks = {
          #   treefmt = treefmtEval.${system}.config.build.check self;
          # };
        };
    });

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
