{ pkgs, ... }: {
  system.stateVersion = "24.11";

  users.mutableUsers = true;
  users.users.root.initialPassword = "nixos";
  users.users.bjeanes = {
    initialPassword = "nixos";
    isNormalUser = true;
    group = "users";
    extraGroups = [ "wheel" "networkmanager" ];
  };
  networking.networkmanager.enable = true;

  nixpkgs.config.pulseaudio = true;

  services.xserver = {
    enable = true;
    desktopManager = {
      xterm.enable = false;
      xfce.enable = true;
    };
  };
  services.displayManager = {
    autoLogin.user = "bjeanes";
    defaultSession = "xfce";
  };

  # programs.firefox.enable = true;
  # programs.firefox.package = pkgs.firefox-bin;
  environment.systemPackages = [ pkgs.firefox-bin ];
}
