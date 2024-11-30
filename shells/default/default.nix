{ inputs, pkgs, ... }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    inputs.self.packages.${system}.nvim
    treefmt
    alejandra
    python310Packages.mdformat
    shfmt
    inputs.nil.packages.${system}.nil
    inputs.snowfall-flake.packages.${system}.flake
    inputs.nixos-generators.packages.${system}.nixos-generate
  ];
}
