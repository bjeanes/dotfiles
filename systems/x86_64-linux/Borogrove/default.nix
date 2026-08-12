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

  networking.hostId = "4942dfbd";
  networking.networkmanager.enable = true;

  services.glances = {
    enable = true;
    openFirewall = true;
  };

  remote-power-management = {
    enable = true;
    user = "homeassistant";
    authorizedKeysFile = ./../../../secrets/homeassistant-key.pub;
  };

  homelab.services = {
    arrs.enable = true;

    # Radarr generates its own API key on first run, so `radarr4k-api-key.age`
    # can't exist until radarr4k has been deployed once. Drop this (and
    # uncomment the secret) once it has.
    recyclarr.radarr4k.enable = false;

    qbittorrent.enable = true;
    forgejo.enable = true;
    silverbullet.enable = true;
    birdnet.enable = true;
    soju.enable = true;
  };

  virtualisation.oci-containers.backend = "podman";
  virtualisation.podman = {
    autoPrune.enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };
  systemd.timers."podman-auto-update".wantedBy = [ "timers.target" ];
}
