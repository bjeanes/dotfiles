# OptiPlex 7070 SFF
#
{
  config,
  flake,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    flake.nixosModules.default
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
    # radarr has 7878
    radarr4k.tailscale.localPort = 7879;
    # birdnet has 8080
    sabnzbd.tailscale.localPort = 8081;
    qbittorrent = {
      enable = true;
      # birdnet has 8080, sabnzbd 8081
      tailscale.localPort = 8082;
    };
    forgejo = {
      enable = true;
      # bookorbit has 3000, tracearr 3001
      tailscale.localPort = 3002;
    };
    silverbullet.enable = true;
    birdnet.enable = true;
    hister.enable = true;
    soju.enable = true;
    tracearr = {
      enable = true;
      # bookorbit has 3000
      tailscale.localPort = 3001;
    };
    bookorbit.enable = true;
    readeck.enable = true;
    affine.enable = true;
    whoami.enable = true;
    miniflux = {
      enable = true;
      hostName = "rss";
    };
  };

  virtualisation.oci-containers.backend = "podman";
  virtualisation.podman = {
    autoPrune.enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };
  systemd.timers."podman-auto-update".wantedBy = [ "timers.target" ];
}
