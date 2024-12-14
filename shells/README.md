# Snowfall `shells/`

See https://snowfall.org/guides/lib/shells/.

Shell definitions are loaded from `./<name>/default.nix` and will be output as a flake `devShells` output by the name of the
directory `<name>`.

The contents of the shell definition file must be a Nix function. It accepts arguments as per the example below:

```nix
{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,

  # You also have access to your flake's inputs.
  inputs,

  # The namespace used for your flake, defaulting to "internal" if not set.
  namespace,

  # All other arguments come from NixPkgs. You can use `pkgs` to pull shells or helpers
  # programmatically or you may add the named attributes as arguments here.
  pkgs,
  mkShell,
  ...
}:

mkShell {
  # Create your shell
  packages = with pkgs; [
  ];
}
```
