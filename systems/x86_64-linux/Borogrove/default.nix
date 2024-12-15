# OptiPlex 7070 SFF
#
{ pkgs, ... }:
{
  snowfallorg.users.bjeanes = { };

  system.stateVersion = "24.11";

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

  services.ssh.enable = true;

  services.tailscale = {
    enable = true;
  };

  services.zerotierone = {
    enable = true;
    joinNetworks = [ "17d709436c21ca93" ];
  };

  environment.systemPackages = [ ];

  programs.git.enable = true;

  programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;
  };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };
}
