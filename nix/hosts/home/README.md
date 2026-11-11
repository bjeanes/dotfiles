# home

This isn't a machine. It's my Home Manager configuration on its own, as I'd
have it on any workstation, independent of a particular host's quirks. Since
it has no `configuration.nix`, blueprint builds no system for it. It only
exposes the standalone home configuration, for each system:

```sh
nix build '.#legacyPackages.x86_64-linux.homeConfigurations."bjeanes@home".activationPackage'
nix build '.#legacyPackages.aarch64-darwin.homeConfigurations."bjeanes@home".activationPackage'
```

Its main use is as the source of the `dotfiles` branch, which renders this
configuration so that it can be used on Linux and macOS without Nix. Rendering a
real host instead would include only what that host happens to enable. For
example, Borogrove is a headless server with no terminal emulators configured.

Feel free to enable here anything that a workstation would have but that the
shared modules leave opt-in.
