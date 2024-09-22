{
  system.stateVersion = "24.11";

  users.mutableUsers = true;
  users.users.root.initialPassword = "nixos";
  users.users.bjeanes = {
    initialHashedPassword = "";
    isNormalUser = true;
    group = "users";
    extraGroups = [ "wheel" "networkmanager" ];
  };
  services.displayManager.autoLogin.user = "bjeanes";
  networking.networkmanager.enable = true;
  programs.sway.enable = true;
}
