# dotfiles

This branch is my home directory as [Home Manager][1] configures it, minus
its dependence on Nix. CI generates it from the Nix flake on [`main`][2], with
one commit here for each commit there that changes the generated files. Each
commit message references the commit it was generated from.

There's a directory for each platform, `linux` and `darwin` (macOS). Each holds
the whole home directory as Home Manager renders it on that platform. Most files
are the same in both. Paths below, such as `~/.local/bin`, are relative to each
of them.

Feel free to take anything you find useful. However, I haven't tested or run
any of it in this form. It's meant as a reference, rather than something to
install as-is.

Please don't open pull requests against this branch. Since CI
regenerates it from `main`, any change made here would be lost.

A few things to know before borrowing from it:

- Nix refers to each command by its full path in the Nix store, which only
  exists on a machine with Nix. Those paths have been stripped back to the
  command's name (e.g. `difft`), on the assumption that it's on your `$PATH`.
  You may need to install some of them first.
- Scripts this configuration generates are in `~/.local/bin`. Other files it
  generates are in `~/.local/share/dotfiles`.
- Plugins and themes from other projects aren't included. The configuration
  still refers to where they would be, so those paths will be empty until you
  fetch them yourself. `~/.local/share/dotfiles/README.md` lists where each one
  comes from.

[1]: https://github.com/nix-community/home-manager
[2]: https://github.com/bjeanes/dotfiles/tree/main
