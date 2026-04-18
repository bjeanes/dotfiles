{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.remote-power-management;
in
{
  options.remote-power-management = {
    enable = lib.mkEnableOption "Enable remote power management";

    user = lib.mkOption {
      type = lib.types.str;
      default = "remote-power-management";
      description = "Username for the remote power management service.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = config.remote-power-management.user;
      description = "Group for the remote power management service. Defaults to the username.";
    };

    authorizedKeysFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing authorized SSH public keys for the
        remote power management user.
      '';
    };

    wolInterface = lib.mkOption {
      type = lib.types.str;
      default = "eno1";
      description = "Name of network interface on which to enable wake-on-LAN";
    };

    allowShutdown = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow the user to shutdown the machine remotely.";
    };

    allowReboot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow the user to reboot the machine remotely.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      shell = pkgs.bash;
      group = cfg.group;
      openssh.authorizedKeys.keyFiles = [
        cfg.authorizedKeysFile
      ];
    };

    users.groups.${cfg.group} = { };

    security.sudo.extraRules = [
      (lib.mkIf cfg.allowShutdown {
        users = [ cfg.user ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl poweroff";
            options = [ "NOPASSWD" ];
          }
        ];
      })
      (lib.mkIf cfg.allowReboot {
        users = [ cfg.user ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl reboot";
            options = [ "NOPASSWD" ];
          }
        ];
      })
    ];

    networking.interfaces.${cfg.wolInterface}.wakeOnLan.enable = true;
  };
}
