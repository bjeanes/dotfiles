{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.homelab.networking.e1000eOffloads;
in
{

  # Works around dropped networking:
  #
  #   May 08 04:59:29 Brillig kernel: e1000e 0000:00:1f.6 eno1: Detected Hardware Unit Hang:
  options.homelab.networking.e1000eOffloads = {
    disable = lib.mkEnableOption ''
      disabling TSO/GSO on an e1000e NIC.

      Workaround for the well-known "Detected Hardware Unit Hang" issue
      on Intel I219 chipsets, which is commonly triggered by VM workloads
      over macvtap or bridged interfaces
    '';

    interface = lib.mkOption {
      type = lib.types.str;
      default = "eno1";
      example = "enp0s31f6";
      description = "Name of the e1000e interface to apply the workaround to.";
    };
  };

  config = lib.mkIf cfg.disable {
    systemd.services."disable-e1000e-offloads" = {
      description = "Disable problematic e1000e offloads on ${cfg.interface}";
      wantedBy = [ "network-online.target" ];
      after = [
        "network-pre.target"
        "sys-subsystem-net-devices-${cfg.interface}.device"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.ethtool}/bin/ethtool -K ${cfg.interface} tso off gso off";
      };
    };
  };
}
