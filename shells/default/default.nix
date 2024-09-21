{ inputs, pkgs, ... }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    treefmt
    alejandra
    python310Packages.mdformat
    shfmt
    inputs.nil.packages.${system}.nil
  ];
}
