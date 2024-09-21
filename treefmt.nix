{ pkgs, ... }: {
  projectRootFile = "flake.lock";

  programs.nixpkgs-fmt.enable = true;
  programs.nixpkgs-fmt.package = pkgs.nixpkgs-fmt;
}
