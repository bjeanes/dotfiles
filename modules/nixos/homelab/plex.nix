{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
let
  svc = "plex";
  coalesce = val: default: if (val == null) then default else val;
in
{
  options.homelab.services.${svc} = {
    enable = lib.mkEnableOption svc;

    configDir = lib.mkOption {
      default = "/var/lib/homelab/${svc}";
      example = "/var/lib/homelab/${svc}";
      type = lib.types.str;
      description = "Location to store ${svc} config";
    };

    timeZone = lib.mkOption {
      default = config.homelab.timeZone;
      type = lib.types.str;
      description = "Time zone for Plex";
    };

    user = lib.mkOption {
      default = coalesce config.homelab.user svc;
      type = lib.types.str;
      description = ''
        User to run Plex service as
      '';
    };

    group = lib.mkOption {
      default = config.homelab.group;
      type = lib.types.str;
      description = ''
        Group to run the Plex service as
      '';
    };

    backupToNAS = lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = "Back up configDir to legacy location on NAS";
    };
  };

  config =
    let
      cfg = config.homelab.services.${svc};
      myLib = lib.${namespace};
      svcName = myLib.containerSvcName config svc;
      setEnvFromCommandsForContainer = myLib.setEnvFromCommandsForContainer config;
      setEnvFromFilesForContainer = myLib.setEnvFromFilesForContainer config;
      secrets = config.age.secrets;

      nasConfigPath = "/nas/docker/media/plex";
      pmsPath = "Library/Application Support/Plex Media Server";
      databasePath = "${pmsPath}/Plug-in Support/Databases";
      databaseBackupPath = "${databasePath}/Backups";

      tmpPaths = [
        "Library/Caches"
        "${pmsPath}/Cache"
        "${pmsPath}/Plug-in Support/Caches"
      ];

      logsPath = "${pmsPath}/Logs";
      transcodePath = "/tmp/plex-transcoding";
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          users.users = {
            ${svc} = {
              isSystemUser = true;
              group = cfg.group;
            };
          };

          users.groups.${cfg.group} = { };

          networking.firewall = {
            allowedTCPPorts = [
              32400
              3005
              8324
              32469
            ];
            allowedUDPPorts = [
              1900
              5353
              32410
              32412
              32413
              32414
            ];
          };

          systemd.tmpfiles.rules =
            let
              # According to tmpfiles.d man page, we should use C-style escapes here.
              #
              # https://www.man7.org/linux/man-pages/man5/tmpfiles.d.5.html#CONFIGURATION_FILE_FORMAT
              e = lib.strings.escapeC [ " " ]; # whitespace is of obvious relevance with Plex path's containing spaces
            in
            [
              # Ensure config directory exists, owned by user
              "d ${e cfg.configDir}                   0775 ${cfg.user} ${cfg.group} - -"
              "d ${e cfg.configDir}/${e logsPath}     0775 ${cfg.user} ${cfg.group} 4w -" # expire logs
              "d ${e transcodePath}                   0775 ${cfg.user} ${cfg.group} 2d -" # expire transcode artifacts

              # If the databases directory doesn't exist, create it and copy latest from NAS
              "C ${e cfg.configDir}/${e databasePath} 0775 ${cfg.user} ${cfg.group} - ${nasConfigPath}/${databasePath}"

              # Ensure directory and contents belong to specified owner and group
              "Z ${e cfg.configDir}                   -    ${cfg.user} ${cfg.group} - -"
            ]

            # Create volumes (if possible) for the caching directories, and set expiries
            ++ (map (d: "v ${e cfg.configDir}/${e d}  0775 ${cfg.user} ${cfg.group} 1w -") tmpPaths);

          virtualisation.oci-containers.containers = {
            ${svc} = {
              image = "plexinc/pms-docker:plexpass";

              extraOptions = [
                "--network=host"
                "--privileged=true"
              ];

              # TODO: instead of interleaving mounts between local and NAS, have a single
              # MergerFS mount point and regularly move large / irregularly accessed files like
              # thumbnails from the local branch to the NAS branch in the MergerFS mount.
              volumes =
                [
                  "/etc/localtime:/etc/localtime:ro"
                  "/dev/dri:/dev/dri:z"

                  "${transcodePath}:/transcode"

                  "/nas/media:/data"

                  # Mount the config from NAS first, so that big files like media thumbnails and previews are stored on the NAS
                  "${nasConfigPath}:/config"

                  # Then, mount the database from a local path so that we aren't writing a SQLite DB over the network
                  "${cfg.configDir}/${databasePath}:/config/${databasePath}"

                  # But make sure those database backups still end up on the NAS
                  "${nasConfigPath}/${databaseBackupPath}:/config/${databaseBackupPath}"

                  # Log files should be local
                  "${cfg.configDir}/${logsPath}:/config/${logsPath}"
                ]
                # Temporary caching should be local
                ++ (map (d: "${cfg.configDir}/${d}:/config/${d}") tmpPaths);

              environment = {
                TZ = "Australia/Melbourne";
                ALLOWED_NETWORKS = myLib.lanSubnet;
                CHANGE_CONFIG_DIR_OWNERSHIP = "false";
              };
            };
          };

          systemd.services = {
            ${svcName} = {
              aliases = [ "plex.service" ];

              requires = [
                "nas-media.automount"
                "nas-docker.automount"
              ];
              upheldBy = [
                "nas-media.automount"
                "nas-docker.automount"
              ];
              after = [
                "nas-media.automount"
                "nas-docker.automount"
              ];
            };
          };
        }

        (setEnvFromCommandsForContainer svc {
          PLEX_UID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
          PLEX_GID = "${pkgs.getent}/bin/getent group homelab | cut -d: -f3";
        })

        (setEnvFromFilesForContainer svc {
          PLEX_CLAIM = secrets.plex-token.path;
        })

        (lib.mkIf cfg.backupToNAS {
          systemd.services."backup-${svc}-to-NAS" = {
            requires = [ "nas-docker.mount" ];
            after = [ "nas-docker.mount" ];
            startAt = "*-*-* 02:00:00 ${cfg.timeZone}";
            serviceConfig = {
              Type = "oneshot";
            };
            script = ''
              set -eu
              ${pkgs.util-linux}/bin/flock /tmp/backup-to-NAS.lock \
                ${pkgs.rsync}/bin/rsync -avuP --no-o --no-g ${lib.escapeShellArg cfg.configDir}/* /nas/docker/media/${svc}/
            '';
          };
        })
      ]
    );

}
