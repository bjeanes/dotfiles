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

  services.glances = {
    enable = true;
    openFirewall = true;
  };

  homelab.networking.e1000eOffloads.disable = true;
  homelab.services.homeassistant = {
    enable = true;
    image.sha256 = "sha256-R0uPLmV/aXx6ImrNW20Lj3Sy39GfcUh6GCONizajYE8=";
    network.macAddress = "52:54:00:3b:95:b0";
    uuid = "3d285dee-b8e3-45dd-9b08-b4dc1fd3eeac";
    usbDevices = [
      #   { ConBee II
      #     vendorId = "0x1cf1";
      #     productId = "0x0030";
      #   }
      #{
      #  # Nabu Casa SkyConnect
      #  vendorId = "0x10c4";
      #  productId = "0xea60";
      #}
      #{
      #  # 2357:0604 TP-Link TP-Link UB500 Adapter
      #  vendorId = "0x2357";
      #  productId = "0x0604";
      #}
    ];
    serialDevices = [
      # ConBee II is unresponsive when exposed as a USB device, so putting it
      # here exposes it as a TTY device at /dev/ttyS1, which Zigbee2MQTT is
      # happy with.

      # "/dev/serial/by-id/usb-dresden_elektronik_ingenieurtechnik_GmbH_ConBee_II_DE2449538-if00"
      "/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_a2e19fcaa678f011a0a0a1e70ba521c7-if00-port0"
      "/dev/serial/by-id/usb-Nabu_Casa_SkyConnect_v1.0_bcdc5f621992ed11b4bdcbd13b20a988-if00-port0"
    ];
  };

  remote-power-management = {
    enable = true;
    user = "homeassistant";
    authorizedKeysFile = ./../../../secrets/homeassistant-key.pub;
  };

  networking.hostId = "cc8e939c";
  networking.networkmanager.enable = true;
}
