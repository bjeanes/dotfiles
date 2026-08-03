{ lib
, config
, pkgs
, namespace
, ...
}:
let
  coalesce = val: default: if (val == null) then default else val;
  myLib = lib.${namespace};

  setEnvFromCommandsForContainer = myLib.setEnvFromCommandsForContainer pkgs config;

  mkArr =
    name:
    { needsMedia ? true
    , image ? "lscr.io/linuxserver/${name}:latest"
    , https ? null
    , configMount ? "/config"
    , funnel ? false
    , # Extra listeners beyond the `https` web UI, in `mkTailscaleServeConfig`
      # spec form (e.g. `[ "6697:6501" ]`). `tlsTcp` has tailscaled terminate
      # TLS and forward plaintext to the target.
      tcp ? [ ]
    , tlsTcp ? [ ]
    , forceUser ? null
    , after ? [ ]
    , ...
    }:
    let
      svcName = myLib.containerSvcName config name;
    in
    {
      imports = builtins.filter (f: lib.hasSuffix "/${name}.nix" f) (
        lib.snowfall.fs.get-non-default-nix-files-recursive ./arr
      );

      options.homelab.services.${name} = {
        enable = lib.mkOption {
          default = config.homelab.services.arrs.enable;
          type = lib.types.bool;
          description = "Enable ${name}";
        };

        tailscale = {
          enable = lib.mkOption {
            default = config.homelab.services.arrs.tailscale.enable;
            type = lib.types.bool;
            description = "Enable Tailscale for ${name}";
          };
        };

        image = lib.mkOption {
          default = image;
          type = lib.types.str;
          description = "OCI image for ${name}";
        };

        after = lib.mkOption {
          default = after;
          type = lib.types.listOf lib.types.str;
          description = "Services to be started before ${name}, if enabled";
        };

        configDir = lib.mkOption {
          default = "/var/lib/homelab/${name}";
          example = "/var/lib/homelab/${name}";
          type = lib.types.str;
          description = "Location to store service config";
        };

        timeZone = lib.mkOption {
          default = config.homelab.timeZone;
          type = lib.types.str;
          description = "Time zone for ${name}";
        };

        backupToNAS = lib.mkOption {
          default = true;
          type = lib.types.bool;
          description = "Back up configDir to legacy location on NAS";
        };
      }
      // (lib.optionalAttrs (forceUser == null) {
        user = lib.mkOption {
          default = coalesce config.homelab.user name;
          type = lib.types.str;
          description = ''
            User to run ${name} service as
          '';
        };

        group = lib.mkOption {
          default = config.homelab.group;
          type = lib.types.str;
          description = ''
            Group to run the ${name} service as
          '';
        };

      });

      config =
        let
          cfg = config.homelab.services.${name};
          tsName = "${name}-tailscale";
        in
        lib.mkIf cfg.enable (
          lib.mkMerge (
            [
              {
                systemd.services.${svcName}.aliases = [ "${name}.service" ];
                systemd.services."${svcName}-tailscale" = {
                  startLimitBurst = 3;
                  startLimitIntervalSec = 1;
                };

                virtualisation.oci-containers = {
                  containers = {
                    ${name} = {
                      image = cfg.image;
                      autoStart = true;
                      volumes = [ "${cfg.configDir}:${configMount}" ];
                      labels = {
                        "io.containers.autoupdate" = "registry";
                      };
                      # extraOptions = [ "--pull=always" ];
                      environment = {
                        TZ = cfg.timeZone;
                        UMASK = "002";
                      };
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
                  concatMap
                    (dir: ([
                      # Ensure config directory exists, owned by user
                      "d ${dir} 0775 ${user} ${group} - -"

                      # Ensure directory and contents belong to specified owner and group
                      "Z ${dir} - ${user} ${group} - -"
                    ]))
                    [
                      cfg.configDir
                    ];
              }
              (lib.optionalAttrs (forceUser == null) (
                {
                  users.users = {
                    "${cfg.user}" = {
                      isSystemUser = true;
                      group = cfg.group;
                    };
                  };
                  users.groups.${cfg.group} = { };
                }
                //
                  # Nix expressions give us no way to derive the UID from a user at
                  # evaluation time, so this delays resolution of user/group names
                  # to UID/GID at service start time, by modifying the
                  # systemd.service record for the docker container.
                  (setEnvFromCommandsForContainer name {
                    PUID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
                    PGID = "${pkgs.getent}/bin/getent group ${cfg.group} | cut -d: -f3";
                  })
              ))
              (lib.optionalAttrs needsMedia {
                virtualisation.oci-containers.containers.${name}.volumes = [
                  "/mnt/nfs/nas/media:/data"
                ];
                systemd.services = {
                  ${svcName} = {
                    bindsTo = [ "mnt-nfs-nas-media.mount" ];
                    after = [ "mnt-nfs-nas-media.mount" ];
                  };
                };
              })
              (lib.mkIf cfg.backupToNAS (
                myLib.buildBackupScriptForDir pkgs name cfg.configDir { inherit (cfg) timeZone; }
              ))
              (lib.mkIf cfg.tailscale.enable {
                virtualisation.oci-containers.containers = {
                  # Set up main service container to use and depend on the network container for Tailscale
                  ${name} = {
                    extraOptions = [
                      "--network=container:${tsName}"
                    ];
                    dependsOn = [ tsName ];
                  };
                };
              })
              (lib.mkIf cfg.tailscale.enable (
                myLib.mkTailscaleContainer pkgs config tsName (
                  {
                    hostname = name;
                    inherit tcp tlsTcp https;
                  }
                  // lib.optionalAttrs funnel { funnel = [ 443 ]; }
                )
              ))
            ]
            ++ (map
              (
                svc:
                (lib.mkIf (config.homelab.services.${svc}.enable) (
                  let
                    self = if (cfg.tailscale.enable) then tsName else svcName;

                    # tailscale conditional temporarily disabled because qBit
                    # doesn't have the `.tailscale.enabled` option, as its
                    # always enabled. I am currently running everything through
                    # tailscale, so content to leave this hardcoded _for now_
                    after =
                      # if (config.homelab.services.${svc}.tailscale.enable) then
                      [
                        "${svc}.service"
                        "${svc}-tailscale.service"
                      ]
                      # else
                      #   ["${svc}.service"];
                    ;
                  in
                  {
                    systemd.services.${self} = {
                      inherit after;
                      requires = after;
                    };
                  }
                ))
              )
              after)
          )
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
        "znc"
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

    (mkArr "znc" {
      image = "lscr.io/linuxserver/znc:latest";

      # ZNC multiplexes webadmin and IRC on a single plaintext listener, so
      # 6501 serves the web UI over HTTPS and 6697 gives clients IRC over TLS,
      # both terminated by tailscaled against the node's cert.
      https = 6501;
      tlsTcp = [ "6697:6501" ];

      needsMedia = false;
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
      image = "ghcr.io/jorenn92/maintainerr:latest";
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

    tailscale = {
      enable = lib.mkOption {
        default = config.homelab.tailscale.enable;
        type = lib.types.bool;
        description = "Enable Tailscale for enabled *arr software, by default";
      };
    };
  };
}
