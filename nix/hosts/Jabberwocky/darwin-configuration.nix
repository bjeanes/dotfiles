{ config, flake, ... }:
{
  imports = [ flake.darwinModules.default ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  system.stateVersion = 5;
  system.defaults.loginwindow.autoLoginUser = "bjeanes";
  system.primaryUser = "bjeanes";
  age.secrets.claude-code-oauth-token.owner = config.system.primaryUser;

  users.users.bjeanes.home = "/Users/bjeanes";
}
