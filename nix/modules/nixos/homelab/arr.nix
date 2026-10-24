{
  lib,
  config,
  pkgs,
  flake,
  ...
}:
let
  myLib = flake.lib;

  mkArr =
    name:
    {
      needsMedia ? true,
      image ? "lscr.io/linuxserver/${name}:latest",
      # Web UI port; `null` for one without
      https ? null,
      configMount ? "/config",
      funnel ? false,
      forceUser ? null,
      after ? [ ],
      exposeAs ? "service",
    }:
    {
      imports = lib.optional (builtins.pathExists ./arr/${name}.nix) ./arr/${name}.nix;

      options.homelab.services.${name} =
        myLib.mkHomelabServiceOptions config name {
          inherit image exposeAs;
          hostName = name;
          withUser = forceUser == null;
        }
        // {
          enable = lib.mkOption {
            default = config.homelab.services.arrs.enable;
            type = lib.types.bool;
            description = "Enable ${name}";
          };

          after = lib.mkOption {
            default = after;
            type = lib.types.listOf lib.types.str;
            description = "Services to be started before ${name}, if enabled";
          };
        };

      config =
        let
          cfg = config.homelab.services.${name};
          podName = "${name}-pod";
          inherit (config.virtualisation.quadlet) pods;
          mediaMount = "mnt-nfs-nas-media.mount";

          # The ones that are enabled on this host
          dependencies = map (svc: "${svc}.service") (
            lib.filter (svc: config.homelab.services.${svc}.enable) cfg.after
          );
        in
        lib.mkIf cfg.enable (
          lib.mkMerge [
            {
              virtualisation.quadlet = {
                pods.${podName} = { };

                containers.${name} = {
                  autoStart = true;
                  containerConfig = {
                    pod = pods.${podName}.ref;
                    image = cfg.image;
                    autoUpdate = "registry";
                    volumes = [
                      "${cfg.configDir}:${configMount}"
                    ]
                    ++ lib.optional needsMedia "/mnt/nfs/nas/media:/data";
                    environments = {
                      TZ = cfg.timeZone;
                      UMASK = "002";
                    };
                  };
                  unitConfig = {
                    After = dependencies ++ lib.optional needsMedia mediaMount;
                    Requires = dependencies;
                    BindsTo = lib.optional needsMedia mediaMount;
                  };
                };
              };
            }
            {
              # https://www.man7.org/linux/man-pages/man5/tmpfiles.d.5.html#SYNOPSIS
              systemd.tmpfiles.rules =
                with lib;
                let
                  user = if forceUser == null then cfg.user else head (splitString ":" forceUser);
                  group = if forceUser == null then cfg.group else head (reverseList (splitString ":" forceUser));
                in
                [
                  # Ensure config directory exists, owned by user
                  "d ${cfg.configDir} 0775 ${user} ${group} - -"

                  # Ensure directory and contents belong to specified owner and group
                  "Z ${cfg.configDir} - ${user} ${group} - -"
                ];
            }
            # Not mkIf: `cfg.user` doesn't exist with forceUser, and mkIf
            # still evaluates attribute names
            (lib.optionalAttrs (forceUser == null) {
              users.users = {
                "${cfg.user}" = {
                  isSystemUser = true;
                  group = cfg.group;
                };
              };
              users.groups.${cfg.group} = { };
            })
            # Nix expressions give us no way to derive the UID from a user at
            # evaluation time, so these resolve at service start.
            (lib.optionalAttrs (forceUser == null) (
              myLib.mkQuadletDynamicEnvironment pkgs config {
                containerName = name;
                variables = {
                  PUID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
                  PGID = "${pkgs.getent}/bin/getent group ${cfg.group} | cut -d: -f3";
                };
              }
            ))
            (lib.mkIf cfg.backupToNAS (
              myLib.buildBackupScriptForDir pkgs name cfg.configDir { inherit (cfg) timeZone; }
            ))
            (myLib.mkTailscaleQuadletExposure pkgs config name (
              { inherit https podName; } // lib.optionalAttrs funnel { funnel = [ 443 ]; }
            ))
          ]
        );
    };
in
{
  imports = [
    # TV Shows
    (mkArr "sonarr" {
      https = 8989;
      after = [
        "prowlarr"
        "qbittorrent"
        "sabnzbd"
      ];
    })

    # Movies
    (mkArr "radarr" {
      https = 7878;
      after = [
        "prowlarr"
        "qbittorrent"
        "sabnzbd"
      ];
    })

    (mkArr "radarr4k" {
      image = "lscr.io/linuxserver/radarr:latest";
      https = 7878;
      after = [
        "prowlarr"
        "qbittorrent"
        "sabnzbd"
      ];
    })

    # Music
    (mkArr "lidarr" {
      https = 8686;
      after = [
        "prowlarr"
        "qbittorrent"
        "sabnzbd"
      ];
    })

    # Books - disabled because it's pretty shit; will look at alternatives
    # (mkArr "readarr" {
    #   https = 8787;
    #   image = "lscr.io/linuxserver/readarr:develop";
    # })

    # Subtitles
    (mkArr "bazarr" { https = 6767; })

    # Indexer aggregation
    (mkArr "prowlarr" {
      https = 9696;
      needsMedia = false;
    })

    # NZB
    (mkArr "sabnzbd" { https = 8080; })

    # Managing media requests
    (mkArr "overseerr" {
      image = "docker.io/sctx/overseerr:latest";
      https = 5055;
      needsMedia = false;
      configMount = "/app/config";
      funnel = true;
      # Services can't be Funnelled
      exposeAs = "sidecar";
      after = [
        "sonarr"
        "radarr"
      ];
    })

    # Reliably unpacking media
    (mkArr "unpackerr" {
      image = "ghcr.io/unpackerr/unpackerr:latest";
      https = 5656;
      after = [
        "sonarr"
        "radarr"
        "lidarr"
      ];
    })

    # Subscribe to private tracker IRC announce channels and auto-download certain torrents
    (mkArr "autobrr" {
      image = "ghcr.io/autobrr/autobrr:latest";
      https = 7474;
      needsMedia = false;
      after = [
        "sonarr"
        "radarr"
      ];
    })

    # https://getqui.com/
    (mkArr "qui" {
      image = "ghcr.io/autobrr/qui:latest";
      https = 7476;
      after = [
        "qbittorrent"
      ];
    })

    # Collect statistics about what is getting watched in Plex, so that I can
    # remove things that aren't being watched if I need to free up space.
    (mkArr "tautulli" {
      image = "ghcr.io/tautulli/tautulli:latest";
      https = 8181;
      needsMedia = false;
      after = [ "plex" ];
    })

    (mkArr "maintainerr" {
      image = "ghcr.io/maintainerr/maintainerr:latest";
      https = 6246;
      needsMedia = false;
      configMount = "/opt/data";
      forceUser = "1000:1000";
      after = [
        "plex"
        "tautulli"
        "sonarr"
        "radarr"
        "overseerr"
      ];
    })

    (mkArr "recyclarr" {
      image = "ghcr.io/recyclarr/recyclarr:latest";
      needsMedia = false;
      forceUser = "1000:1000";
      after = [
        "sonarr"
        "radarr"
      ];
    })
  ];

  options.homelab.services.arrs = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable the *arr suite";
    };
  };
}
