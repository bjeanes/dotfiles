# Snowfall `systems/`

See https://snowfall.org/guides/lib/systems/.

Create a Nix file for each system/host at `systems/<target>/<hostname>/default.nix` where `<target>` is a string
corresponding to a Nix system identifier (e.g. `aarch64-darwin`, `x86_64-linux`).

Each system definition looks something like:

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

    # All other arguments come from the system system.
    config,
    ...
}:
{
    my.config.here = 123;

    snowfallorg.users.my-user = {
        create = true;                  # Defaults to true
        admin = true;                   # Defaults to true

        home = {
            enable = true;              # Defaults to true
            path = "/mnt/home/my-user"; # Defaults to sane place for both macOS and Linux

            config = {};                # Passed to Home Manager
        };
    };
}
```
