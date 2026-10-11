# Everything a NixOS host here gets
{ flake, inputs, ... }:
{
  imports = [
    flake.modules.shared.host
  ]
  ++ builtins.attrValues (removeAttrs flake.nixosModules [ "default" ])
  ++ (with inputs; [
    agenix.nixosModules.default
    comin.nixosModules.comin
    catppuccin.nixosModules.catppuccin
    nixvirt.nixosModules.default
    quadlet-nix.nixosModules.quadlet
    nix-index-database.nixosModules.default
    { programs.nix-index-database.comma.enable = true; }
    flake.modules.shared.secrets
  ]);
}
