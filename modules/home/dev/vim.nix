{
  inputs,
  system,
  lib,
  ...
}:
let
  nvim = inputs.self.packages.${system}.kvim.extend {
    viAlias = lib.mkForce true;
    vimAlias = lib.mkForce true;
  };
in
{
  # If I want to explose minimal versions of this to different systems, there is .extend.appstream
  # https://github.com/nix-community/nixvim/blob/05331006/docs/platforms/standalone.md#extending-an-existing-configuration
  home.packages = [
    nvim
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  home.shellAliases.vimdiff = "nvim -d";
}
