{ inputs, system, ... }: {
  # If I want to explose minimal versions of this to different systems, there is .extend.appstream
  # https://github.com/nix-community/nixvim/blob/05331006/docs/platforms/standalone.md#extending-an-existing-configuration
  home.packages = [ inputs.self.packages.${system}.nvim ];
}
