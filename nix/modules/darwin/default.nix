# Everything a nix-darwin host here gets
{ flake, inputs, ... }:
{
  imports = [
    flake.modules.shared.host
  ]
  ++ builtins.attrValues (removeAttrs flake.darwinModules [ "default" ])
  ++ (with inputs; [
    agenix.darwinModules.default
    nix-index-database.darwinModules.nix-index
    { programs.nix-index-database.comma.enable = true; }
    flake.modules.shared.secrets
  ]);
}
