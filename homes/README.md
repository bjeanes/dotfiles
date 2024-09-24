# Snowfall `homes/`

https://snowfall.org/reference/lib/#flake-structure

```
├─ homes/ (optional homes configurations)
│  │
│  │ A directory named after the `home` type that will be used for all homes within.
│  │
│  │ The architecture is any supported architecture of NixPkgs, for example:
│  │  - x86_64
│  │  - aarch64
│  │  - i686
│  │
│  │ The format is any supported NixPkgs format *or* a format provided by either nix-darwin
│  │ or nixos-generators. However, in order to build systems with nix-darwin or nixos-generators,
│  │ you must add `darwin` and `nixos-generators` inputs to your flake respectively. Here
│  │ are some example formats:
│  │  - linux
│  │  - darwin
│  │  - iso
│  │  - install-iso
│  │  - do
│  │  - vmware
│  │
│  │ With the architecture and format together (joined by a hyphen), you get the name of the
│  │ directory for the home type.
│  └─ <architecture>-<format>/
│     │
│     │ A directory that contains a single home's configuration. The directory name
│     │ will be the name of the home.
│     └─ <home-name>/
│        │
│        │ A NixOS module for your home's configuration.
│        └─ default.nix
```
