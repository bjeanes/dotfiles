# OptiPlex 7070 SFF
#
{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}:
{
  snowfallorg.users.bjeanes = { };

  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "24.11";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  time.timeZone = "Australia/Melbourne";

  users.mutableUsers = true;
  users.users.bjeanes = {
    isNormalUser = true;
    group = "users";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.zsh;
    hashedPasswordFile = config.age.secrets.default-password.path;
  };

  networking.networkmanager.enable = true;

  services.glances.enable = true;
}
