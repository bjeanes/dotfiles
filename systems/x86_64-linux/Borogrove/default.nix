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

  homelab.services.arrs.enable = true;
  homelab.services.qbittorrent.enable = true;
  homelab.services.forgejo.enable = true;

  virtualisation.oci-containers.backend = "podman";
  virtualisation.podman = {
    autoPrune.enable = true;
    dockerCompat = true;
  };
}
