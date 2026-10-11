# Everything a home here gets
{ flake, inputs, ... }:
{
  imports =
    (with inputs; [
      _1password-shell-plugins.hmModules.default
      catppuccin.homeModules.catppuccin
      agenix.homeManagerModules.default
      quadlet-nix.homeManagerModules.quadlet
      nix-index-database.homeModules.default
      { programs.nix-index-database.comma.enable = true; }
      flake.modules.shared.secrets
    ])
    ++ builtins.attrValues (removeAttrs flake.homeModules [ "default" ]);
}
