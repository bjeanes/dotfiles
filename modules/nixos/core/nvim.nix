{
  inputs,
  lib,
  system,
  ...
}:
{
  environment.systemPackages = [
    (inputs.self.packages.${system}.nvim.extend {
      viAlias = lib.mkForce true;
      vimAlias = lib.mkForce true;
    })
  ];

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
