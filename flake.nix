{
  inputs = {
    # To update nixpkgs (and thus NixOS), pick the nixos-unstable rev from
    # https://status.nixos.org/
    #
    # This ensures that we always use the official nix cache.
    nixpkgs.url = "github:nixos/nixpkgs/ecd26a469ac56357fd333946a99086e992452b6a";

    darwin.url = "github:lnl7/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    ghostty.url = "github:ghostty-org/ghostty";
    ghostty.inputs.nixpkgs-unstable.follows = "nixpkgs";
    ghostty.inputs.flake-compat.follows = "snowfall-lib/flake-compat";

    docker-inspect-run-cmd-fmt = {
      url = "https://gist.github.com/8ce9c75d518b6eb863f667442d7bc679.git?ref=main";
      flake = false;
      type = "git";
    };

    agenix.url = "github:yaxitech/ragenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    # According to cache.lix.systems:
    #
    #   > there is no caching for any builds of Lix except the ones for the
    #   > exact nixpkgs that release versions of Lix were released with, so you
    #   > will probably not get a cache hit. This is not a bug.
    #
    # So, we will NOT `follow` our unstable nixpkgs
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.92.0.tar.gz";
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

    comin = {
      url = "github:nlewo/comin";
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

    # https://developer.1password.com/docs/cli/shell-plugins/nix/
    _1password-shell-plugins = {
      url = "github:1Password/shell-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "snowfall-lib/flake-utils-plus/flake-utils";
    };

    # nix-index-database.url = "github:nix-community/nix-index-database";
    # nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

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
    let
      secrets =
        { lib, ... }:
        {
          age.secrets =
            with lib;
            listToAttrs (
              map (name: {
                name = removeSuffix ".age" name;
                value = {
                  file = (snowfall.fs.get-file "secrets/${name}");
                };
              }) (attrNames (import (snowfall.fs.get-file "secrets/secrets.nix")))
            );
        };
    in
    (inputs.snowfall-lib.mkFlake {
      inherit inputs;
      src = ./.;

      channels-config = {
        allowUnfree = true;
      };

      overlays = with inputs; [
        darwin.overlays.default
        snowfall-flake.overlays.default
        lix-module.overlays.default
      ];

      systems.modules.darwin = with inputs; [
        agenix.darwinModules.default
        secrets
      ];

      systems.modules.nixos = with inputs; [
        comin.nixosModules.comin
        catppuccin.nixosModules.catppuccin
        agenix.nixosModules.default
        secrets
      ];

      homes.modules = with inputs; [
        _1password-shell-plugins.hmModules.default
        catppuccin.homeManagerModules.catppuccin
        agenix.homeManagerModules.default
        secrets
      ];

      alias = {
        packages.default = "switch";
      };

      outputs-builder =
        channels:
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
      "https://cache.lix.systems"
      "https://ghostty.cachix.org"
    ];
    extra-trusted-public-keys = [
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
      "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
