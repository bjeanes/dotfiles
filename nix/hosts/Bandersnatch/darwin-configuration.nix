{ flake, ... }:
{
  imports = [ flake.darwinModules.default ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  system.stateVersion = 5;
  system.defaults.loginwindow.autoLoginUser = "bjeanes";
  system.primaryUser = "bjeanes";

  users.users.bjeanes.home = "/Users/bjeanes";
}
