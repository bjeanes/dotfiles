{
  inputs,
  pkgs,
  system,
  ...
}:

pkgs.mkShell {
  nativeBuildInputs =
    (with pkgs; [
      treefmt
      alejandra
      # python310Packages.mdformat
      shfmt
    ])
    ++ (with inputs; [
      self.packages.${system}.nvim
      nil.packages.${system}.nil
      snowfall-flake.packages.${system}.flake
      nixos-generators.packages.${system}.nixos-generate
      agenix.packages.${system}.default
    ]);
}
