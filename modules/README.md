# Snowfall `modules/`

See https://snowfall.org/guides/lib/modules/

Files in this directory are [Nix Modules](https://nixos.wiki/wiki/NixOS_modules).

Snowfall automatically looks for and loads modules in the following location: `./{darwin,nixos,home}/*/default.nix`, depending on the current target, and provides the following attribute set as arguments:

```nix
{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # An instance of `pkgs` with your overlays and packages applied is also available.
  pkgs,
  # You also have access to your flake's inputs.
  inputs,

  # Additional metadata is provided by Snowfall Lib.
  namespace, # The namespace used for your flake, defaulting to "internal" if not set.
  system, # The system architecture for this host (eg. `x86_64-linux`).
  target, # The Snowfall Lib target for this system (eg. `x86_64-iso`).
  format, # A normalized name for the system target (eg. `iso`).
  virtual, # A boolean to determine whether this system is a virtual target using nixos-generators.
  systems, # An attribute map of your defined hosts.

  # All other arguments come from the module system.
  config,
  ...
}:
{
  # Your configuration.
}
```

## Resources

- https://snowfall.org/guides/lib/modules/
- https://nixos.wiki/wiki/NixOS_modules
- https://nix.dev/tutorials/module-system/deep-dive
- https://nixos.asia/en/nix-modules
