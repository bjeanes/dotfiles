{
  lib,
  perSystem,
  ...
}:
{
  environment.systemPackages = [
    (perSystem.self.nvim.extend {
      viAlias = lib.mkForce true;
      vimAlias = lib.mkForce true;
    })
  ];

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
