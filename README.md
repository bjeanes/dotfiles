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
