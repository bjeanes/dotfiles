{
  config,
  lib,
  flake,
  pkgs,
  ...
}:
let
  svc = "plex";
in
{
  options.homelab.services.${svc} =
    flake.lib.mkHomelabServiceOptions config svc {
      withUser = true;
    }
    // {
      tailscale = {
        enable = lib.mkOption {
          default = config.homelab.tailscale.enable;
          type = lib.types.bool;
          description = "Enable Tailscale for ${svc}";
        };
      };
    };

  config =
    let
      cfg = config.homelab.services.${svc};
      tsName = "${svc}-tailscale";
      myLib = flake.lib;
      mkTailscaleQuadletContainer = myLib.mkTailscaleQuadletContainer pkgs config;
      mkQuadletDynamicEnvironment = myLib.mkQuadletDynamicEnvironment pkgs config;
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

      firewallPorts = {
        tcp = [
          32400 # PMS
          # 8324 # Plex for Roku via Plex Companion
          32469 # Plex DLNA Server
        ];
        udp = [
          1900 # Plex DLNA Server
          32410 # GDM network discovery
          32412 # GDM network discovery
          32413 # GDM network discovery
          32414 # GDM network discovery
        ];
      };

      publishPorts =
        (map (port: "${toString port}:${toString port}/tcp") firewallPorts.tcp)
        ++ (map (port: "${toString port}:${toString port}/udp") firewallPorts.udp);

      podName = "${svc}-pod";
      inherit (config.virtualisation.quadlet) pods;

      mounts = [
        "mnt-nfs-nas-media.mount"
        "mnt-nfs-nas-docker.mount"
      ];

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
              "d ${e cfg.configDir}/${e pmsPath}      0775 ${cfg.user} ${cfg.group} - -"
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
            ++ (map (d: "d ${e cfg.configDir}/${e d}  0775 ${cfg.user} ${cfg.group} 1w -") tmpPaths);

          virtualisation.quadlet = {
            # Ports are published by the pod, so they're there whether or not
            # the Tailscale sidecar is in it.
            pods.${podName}.podConfig = { inherit publishPorts; };

            containers.${svc} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                autoUpdate = "registry";
                image = "lscr.io/linuxserver/plex:latest";

                devices = [ "/dev/dri:/dev/dri" ];

                # TODO: instead of interleaving mounts between local and NAS, have a single
                # MergerFS mount point and regularly move large / irregularly accessed files like
                # thumbnails from the local branch to the NAS branch in the MergerFS mount.
                volumes = [
                  "/etc/localtime:/etc/localtime:ro"
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

                environments = {
                  TZ = "Australia/Melbourne";
                  # Use the PMS bundled in the image rather than updating at
                  # container start, so `podman auto-update` alone decides the
                  # version and its rollbacks restore the previous one.
                  VERSION = "docker";
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

                # Gives `podman auto-update` something to roll back on. The
                # start period allows for `DOCKER_MODS` installing ahead of PMS.
                healthCmd = "curl -fsS -o /dev/null http://localhost:32400/identity";
                healthInterval = "30s";
                healthTimeout = "5s";
                healthRetries = 3;
                healthStartPeriod = "2m";
              };
              unitConfig = {
                BindsTo = mounts;
                After = mounts;
              };
            };
          };
        }

        # Nix expressions give us no way to derive the UID from a user at
        # evaluation time, so these resolve at service start.
        (mkQuadletDynamicEnvironment {
          containerName = svc;
          variables = {
            PUID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
            PGID = "${pkgs.getent}/bin/getent group ${cfg.group} | cut -d: -f3";
          };
        })

        (lib.mkIf cfg.backupToNAS (
          myLib.buildBackupScriptForDir pkgs svc cfg.configDir { inherit (cfg) timeZone; }
        ))

        (lib.mkIf cfg.tailscale.enable (
          mkTailscaleQuadletContainer tsName {
            inherit podName;
            hostname = svc;
            https = 32400;
          }
        ))

        (lib.mkIf cfg.tailscale.enable {
          homelab.dashboard.entries.${svc} = {
            href = "https://${svc}.${config.homelab.tailscale.tailnet}/web";
            group = "Media";
            icon = "plex.png";
          };
        })
      ]
    );

}
