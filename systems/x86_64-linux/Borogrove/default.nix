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
    ./nas-nfs.nix
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
  };

  networking.networkmanager.enable = true;

  services.openssh.enable = true;

  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth.path;
    extraUpFlags = [
      "--advertise-tags=tag:home,tag:server"
    ];
  };

  services.zerotierone = {
    enable = true;
    joinNetworks = [ "17d709436c21ca93" ];
  };

  services.glances.enable = true;

  environment.systemPackages = [
    (inputs.self.packages.${system}.nvim.extend {
      viAlias = lib.mkForce true;
      vimAlias = lib.mkForce true;
    })
  ];

  programs.git.enable = true;

  programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;
  };

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
