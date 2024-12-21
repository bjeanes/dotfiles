{ config, lib, modulesPath, ... }:
{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "uas" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  services.zfs.autoScrub.enable = true;

  fileSystems."/" =
    {
      device = "zpool/root";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  fileSystems."/nix" =
    {
      device = "zpool/nix";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  fileSystems."/var" =
    {
      device = "zpool/var";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  fileSystems."/home" =
    {
      device = "zpool/home";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-id/nvme-Micron_2200S_NVMe_512GB__19502564DB40-part1";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices =
    [
      {
        device = "/dev/disk/by-id/nvme-Micron_2200S_NVMe_512GB__19502564DB40-part2";
        randomEncryption = true;
      }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
