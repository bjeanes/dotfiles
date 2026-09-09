# Google Pixel Slate (board codename "nocturne"), Amber Lake Y, 12.3" 3000x2000
# touchscreen. Stock ChromeOS firmware replaced with MrChromebox coreboot+edk2,
# so this behaves as an ordinary UEFI x86_64 machine.
#
# See ./nocturne.md for the hardware notes: what's wired how, what's known
# broken, and how to re-flash or restore the device.
# See https://github.com/kabili207/nocturne-linux for prior art.
#
# Intended role: wall-mounted Home Assistant dashboard / kiosk.
#
{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
{
  snowfallorg.users.bjeanes = { };

  imports = [
    ./hardware-configuration.nix # generated; don't edit
    ./hardware.nix # nocturne-specific hardware enablement
    ./audio.nix # Intel AVS: firmware, UCM2, module options
    ./session.nix # kiosk vs interactive desktop, and the panel user
    ./power.nix # never sleep; power button toggles the display
  ];

  # --- The panel's own knobs, consumed by ./session.nix --------------------
  panel = {
    dashboardUrl = "http://${lib.${namespace}.hosts.homeassistant.lan}:8123/";

    interactive = false;
  };

  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Australia/Melbourne";

  networking.hostId = "ead7048e";
  networking.networkmanager.enable = true;

  users.users.bjeanes = {
    isNormalUser = true;
    group = "users";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
      # /dev/snd is ACL'd to the seat holder (tablet); this is for SSH.
      "audio"
    ];
    shell = pkgs.zsh;
    hashedPasswordFile = config.age.secrets.default-password.path;
  };

  services.glances = {
    enable = true;
    openFirewall = true;
  };

  # Fanless: take builder overflow one job at a time.
  nix.settings.max-jobs = 1;
}
