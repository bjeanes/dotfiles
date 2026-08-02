{
  lib,
  namespace,
  ...
}:
{
  buildBackupScriptForDir =
    pkgs: name: dir:
    {
      timeZone ? "Australia/Melbourne",
    }:
    let
      targetDir = "/mnt/nfs/nas/backups/${name}";
    in
    {
      systemd.services."backup-${name}-to-NAS" = {
        startAt = "*-*-* 02:00:00 ${timeZone}";
        unitConfig.RequiresMountsFor = [
          dir
          targetDir
        ];
        serviceConfig = {
          Type = "oneshot";
        };
        script = ''
          set -eu
          ${pkgs.util-linux}/bin/flock /tmp/backup-to-NAS.lock \
            ${pkgs.rsync}/bin/rsync -avuP --no-o --no-g ${lib.escapeShellArg dir}/* ${lib.escapeShellArg targetDir}/
        '';
      };
    };
}
