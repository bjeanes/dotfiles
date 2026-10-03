# Bo's Dot Files

## Install

- Install Nix, using determinate systems' installer:

  ```sh-session
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  ```

- First time run:

  ```sh-session
  sudo nixos-rebuild switch --flake github:bjeanes/dotfiles#<hostname>

  # or (if hostname already matches one defined)

  nix run --extra-experimental-features "nix-command flakes"
  ```

- First time run on macOS:

  The customised `nix.linux-builder` VM is an aarch64-linux system that isn't in
  any binary cache, and a fresh Mac has no Linux builder to build it with. Use
  the `-bootstrap` variant of the host first: it runs the stock builder from
  cache.nixos.org, which then builds the real one on the next switch.

  ```sh-session
  sudo nix run nix-darwin -- switch --flake github:bjeanes/dotfiles#<hostname>-bootstrap
  nix run --extra-experimental-features "nix-command flakes"
  ```
