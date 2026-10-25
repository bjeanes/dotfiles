{
  inputs,
  pkgs,
  system,
  ...
}:

let
  # Evaluates and builds on the target, so the working copy deploys without
  # committing or building anything for Linux locally.
  push-local-flake = pkgs.writeShellApplication {
    name = "push-local-flake";
    runtimeInputs = with pkgs; [
      jq
      jujutsu
    ];
    text = ''
      if [[ $# -lt 1 || $# -gt 2 ]]; then
        echo "usage: push-local-flake <Host> [test|switch|boot|dry-activate]" >&2
        exit 1
      fi

      host="$1"
      action="''${2:-test}"
      target="''${host,,}"

      cd "$(jj root)"

      # Flakes only see files git tracks, which new files aren't until jj
      # snapshots them
      jj status >/dev/null

      src="$(nix flake archive --json --to "ssh-ng://$target" | jq -r .path)"

      ssh -t "$target" sudo nixos-rebuild "$action" --flake "path:$src#$host"
    '';
  };
in
pkgs.mkShell {
  nativeBuildInputs =
    (with pkgs; [
      treefmt
      nixfmt
      # python310Packages.mdformat
      shfmt
      nh
      push-local-flake
    ])
    ++ (with inputs; [
      self.packages.${system}.nvim
      nixos-generators.packages.${system}.nixos-generate
      agenix.packages.${system}.default
    ]);
}
