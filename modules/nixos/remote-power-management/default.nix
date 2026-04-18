{ lib, config, ... }:
let
  cfg = config.remote-power-management;
in
{
  options.remote-power-management = {
    enable = lib.mkEnableOption "Enable remote power management";

    username = lib.mkOption {
      type = lib.types.str;
      default = "remote-power-management";
      description = "Username for the remote power management service.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = config.remote-power-management.username;
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
    users.users.${cfg.username} = {
      isSystemUser = true;
      group = cfg.group;
      openssh.authorizedKeys.keysFile = cfg.authorizedKeysFile;
    };

    users.groups.${cfg.group} = {};

    security.sudo.extraRules = lib.mkOverride 900 [
      (lib.mkIf cfg.allowShutdown {
        userName = cfg.username;
        groups = [ cfg.group ];
        commands = [
          {
            command = "${config.systemd.package}/bin/systemctl poweroff";
            options = [ "NOPASSWD" ];
          }
        ];
      })
      (lib.mkIf cfg.allowReboot {
        userName = cfg.username;
        groups = [ cfg.group ];
        commands = [
          {
            command = "${config.systemd.package}/bin/systemctl reboot";
            options = [ "NOPASSWD" ];
          }
        ];
      })
    ];

    networking.wakeOnLan.enable = true;
  };
}
