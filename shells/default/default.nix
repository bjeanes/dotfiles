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
      nh
    ])
    ++ (with inputs; [
      self.packages.${system}.nvim
      nil.packages.${system}.nil
      nixos-generators.packages.${system}.nixos-generate
      agenix.packages.${system}.default
    ]);
}
