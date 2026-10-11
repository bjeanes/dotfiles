{
  inputs = {
    # To update nixpkgs (and thus NixOS), pick the nixos-unstable rev from
    # https://status.nixos.org/
    #
    # This ensures that we always use the official nix cache.
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-unstable";
    };

    nixvirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin.url = "github:lnl7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    ghostty.url = "github:ghostty-org/ghostty";

    # Pixel Slate ("nocturne") hardware support: AVS audio firmware/topology
    # blobs extracted from ChromeOS, ALSA UCM2 profile, modprobe options,
    # WirePlumber tweaks and libinput quirks. Not a flake; we just read files
    # out of the tree. See nix/hosts/Tulgey/nocturne.md
    nocturne-linux = {
      url = "github:kabili207/nocturne-linux";
      flake = false;
    };

    docker-inspect-run-cmd-fmt = {
      url = "https://gist.github.com/8ce9c75d518b6eb863f667442d7bc679.git";
      flake = false;
      type = "git";
    };

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    catppuccin.url = "github:catppuccin/nix";

    blueprint = {
      url = "github:numtide/blueprint";
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
        flake-parts.follows = "flake-parts";
      };
    };

    # https://developer.1password.com/docs/cli/shell-plugins/nix/
    _1password-shell-plugins = {
      url = "github:1Password/shell-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    nil = {
      url = "github:oxalica/nil";
      inputs.nixpkgs.follows = "nixpkgs";
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
      # A fresh Mac has no aarch64-linux builder to build our customised
      # linux-builder, so first activation uses the stock one from
      # cache.nixos.org; the next normal switch then builds the real one.
      linuxBuilderBootstrap =
        { lib, pkgs, ... }:
        {
          nix.linux-builder = {
            package = lib.mkForce pkgs.darwin.linux-builder;
            config = lib.mkForce { };
            systems = lib.mkForce [ "aarch64-linux" ];
          };
        };

      flake = inputs.blueprint {
        inherit inputs;
        prefix = "nix";

        systems = [
          "aarch64-darwin"
          "x86_64-linux"
        ];

        nixpkgs = {
          config.allowUnfree = true;
          overlays = [ inputs.nix-darwin.overlays.default ];
        };
      };
    in
    flake
    // {
      darwinConfigurations =
        flake.darwinConfigurations
        // inputs.nixpkgs.lib.mapAttrs' (
          name: system:
          inputs.nixpkgs.lib.nameValuePair "${name}-bootstrap" (
            system.extendModules { modules = [ linuxBuilderBootstrap ]; }
          )
        ) flake.darwinConfigurations;
    };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://ghostty.cachix.org"
    ];
    extra-trusted-public-keys = [
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
