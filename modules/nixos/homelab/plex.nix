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

      nasConfigPath = "/mnt/nfs/nas/docker/media/plex";
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
              "d ${e cfg.configDir}/${pmsPath}        0775 ${cfg.user} ${cfg.group} - -"
              "d ${e cfg.configDir}/${e logsPath}     0775 ${cfg.user} ${cfg.group} 4w -" # expire logs
              "d ${e transcodePath}                   0775 ${cfg.user} ${cfg.group} 2d -" # expire transcode artifacts

              # NOTE: disabled because trying to copy from the network in tmpfiles.d will cause boot to hang indefinitely if the mount isn't ready
              # # If the databases directory doesn't exist, create it and copy latest from NAS
              # "C ${e cfg.configDir}/${e databasePath} 0775 ${cfg.user} ${cfg.group} - ${nasConfigPath}/${databasePath}"
              "d ${e cfg.configDir}/${e databasePath} 0775 ${cfg.user} ${cfg.group} - -" # replacement until I can think of a way to manage this more smoothly, maybe adding a timeout to the tmpfiles service?

              # Ensure directory and contents belong to specified owner and group
              "Z ${e cfg.configDir}                   -    ${cfg.user} ${cfg.group} - -"
            ]

            # Create volumes (if possible) for the caching directories, and set expiries
            ++ (map (d: "v ${e cfg.configDir}/${e d}  0775 ${cfg.user} ${cfg.group} 1w -") tmpPaths);

          virtualisation.oci-containers.containers = {
            ${svc} = {
              image = "lscr.io/linuxserver/plex:latest";

              extraOptions = [
                "--network=host"
              ];

              # TODO: instead of interleaving mounts between local and NAS, have a single
              # MergerFS mount point and regularly move large / irregularly accessed files like
              # thumbnails from the local branch to the NAS branch in the MergerFS mount.
              volumes =
                [
                  "/etc/localtime:/etc/localtime:ro"
                  "/dev/dri:/dev/dri:z"
                  "${secrets.plex-token.path}:/run/secrets/plex-claim"
                  "${transcodePath}:/transcode"

                  "/mnt/nfs/nas/media:/data" # TV Shows, Movies, Music, etc

                  # Base config is local, in particular /config/Library, which
                  # LSIO's Plex checks owner. If it doesn't match it performs
                  # a lengthly and permission-denied attempt to chown, which
                  # we want to avoid.
                  "${cfg.configDir}:/config"

                  # A lot of large metadata files, thumbnails, etc, are stored
                  # here, so let's put that straight on the NAS instead
                  "${nasConfigPath}/${pmsPath}:/config/${pmsPath}"

                  # We want the SQLite DB to be local though, but it's a subpath of pmsPath, so overlay DB location locally
                  "${cfg.configDir}/${databasePath}:/config/${databasePath}"

                  # But... make sure those database backups still end up on the NAS
                  "${nasConfigPath}/${databaseBackupPath}:/config/${databaseBackupPath}"

                  # Log files should be local
                  "${cfg.configDir}/${logsPath}:/config/${logsPath}"
                ]
                # Temporary caching should be local
                ++ (map (d: "${cfg.configDir}/${d}:/config/${d}") tmpPaths);

              environment = {
                TZ = "Australia/Melbourne";
                VERSION = "latest";
                FILE__PLEX_CLAIM = "/run/secrets/plex-claim";
                DOCKER_MODS = "linuxserver/mods:universal-stdout-logs";
                LOGS_TO_STDOUT = lib.concatMapStringsSep "|" (log: "/config/${logsPath}/${log}.log") [
                  "Plex Crash Uploader"
                  "Plex Media Server"
                  "Plex Tuner Service"
                  "PMS Plugin Logs/com.plexapp.agents.fanarttv"
                  "PMS Plugin Logs/com.plexapp.agents.imdb"
                  "PMS Plugin Logs/com.plexapp.agents.lastfm"
                  "PMS Plugin Logs/com.plexapp.agents.localmedia"
                  "PMS Plugin Logs/com.plexapp.agents.movieposterdb"
                  "PMS Plugin Logs/com.plexapp.agents.none"
                  "PMS Plugin Logs/com.plexapp.agents.plexthememusic"
                  "PMS Plugin Logs/com.plexapp.agents.themoviedb"
                  "PMS Plugin Logs/com.plexapp.agents.thetvdb"
                  "PMS Plugin Logs/com.plexapp.system"
                ];
              };
            };
          };

          systemd.services = {
            ${svcName} = {
              aliases = [ "plex.service" ];

              requires = [
                "mnt-nfs-nas-media.mount"
                "mnt-nfs-nas-docker.mount"
              ];
              upheldBy = [
                "mnt-nfs-nas-media.mount"
                "mnt-nfs-nas-docker.mount"
              ];
              after = [
                "mnt-nfs-nas-media.mount"
                "mnt-nfs-nas-docker.mount"
              ];
            };
          };
        }

        (setEnvFromCommandsForContainer svc {
          PUID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
          PGID = "${pkgs.getent}/bin/getent group homelab | cut -d: -f3";
        })

        (lib.mkIf cfg.backupToNAS {
          systemd.services."backup-${svc}-to-NAS" = {
            requires = [ "mnt-nfs-nas-docker.mount" ];
            after = [ "mnt-nfs-nas-docker.mount" ];
            startAt = "*-*-* 02:00:00 ${cfg.timeZone}";
            serviceConfig = {
              Type = "oneshot";
            };
            script = ''
              set -eu
              ${pkgs.util-linux}/bin/flock /tmp/backup-to-NAS.lock \
                ${pkgs.rsync}/bin/rsync -avuP --no-o --no-g ${lib.escapeShellArg cfg.configDir}/* /mnt/nfs/nas/docker/media/${svc}/
            '';
          };
        })
      ]
    );

}
