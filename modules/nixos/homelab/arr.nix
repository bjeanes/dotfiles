{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  coalesce = val: default: if (val == null) then default else val;
  myLib = lib.${namespace};

  setEnvFromFilesForContainer = myLib.setEnvFromFilesForContainer config;
  setEnvFromCommandsForContainer = myLib.setEnvFromCommandsForContainer config;

  mkArr =
    name:
    {
      needsMedia ? true,
      image ? "lscr.io/linuxserver/${name}:latest",
      port ? null,
      configMount ? "/config",
      funnel ? false,
      forceUser ? null,
      ...
    }:
    let
      svcName = myLib.containerSvcName config name;
    in
    {
      imports = builtins.filter (f: lib.hasSuffix "/${name}.nix" f) (
        lib.snowfall.fs.get-non-default-nix-files-recursive ./arr
      );

      options.homelab.services.${name} =
        {
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
          lib.mkMerge [
            {
              systemd.services.${svcName}.aliases = [ "${name}.service" ];

              virtualisation.oci-containers = {
                containers = {
                  ${name} = {
                    image = cfg.image;
                    autoStart = true;
                    volumes = [ "${cfg.configDir}:${configMount}" ];
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
                  requires = [ "mnt-nfs-nas-media.mount" ];
                  upheldBy = [ "mnt-nfs-nas-media.mount" ];
                  after = [ "mnt-nfs-nas-media.mount" ];
                };
              };
            })
            (lib.mkIf cfg.backupToNAS {
              systemd.services."backup-${name}-to-NAS" = {
                requires = [ "mnt-nfs-nas-docker.mount" ];
                after = [ "mnt-nfs-nas-docker.mount" ];
                startAt = "*-*-* 02:00:00 ${cfg.timeZone}";
                serviceConfig = {
                  Type = "oneshot";
                };
                script = ''
                  set -eu
                  ${pkgs.util-linux}/bin/flock /tmp/backup-to-NAS.lock \
                    ${pkgs.rsync}/bin/rsync -avuP --no-o --no-g ${lib.escapeShellArg cfg.configDir}/* /mnt/nfs/nas/docker/media/${name}/
                '';
              };
            })
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
              myLib.mkTailscaleContainer pkgs config tsName {
                hostname = name;
                serve = (
                  lib.optionalAttrs (port != null) (
                    let
                      endpoint = "\${TS_CERT_DOMAIN}:443";
                    in
                    {
                      TCP."443".HTTPS = true;
                      Web.${endpoint}.Handlers."/".Proxy = "http://127.0.0.1:${builtins.toString port}";
                    }
                    # the lib.optionalAttrs _shouldn't_ be necessary, but
                    # because of
                    # https://github.com/tailscale/tailscale/issues/14682 it
                    # results in Tailscale dashboard misleadingly saying the
                    # machine has a funnel.
                    // (lib.optionalAttrs funnel {
                      AllowFunnel.${endpoint} = funnel;
                    })
                  )
                );
              }
            ))
          ]
        );
    };
in
{
  imports = [
    # TV Shows
    (mkArr "sonarr" { port = 8989; })

    # Movies
    (mkArr "radarr" { port = 7878; })

    # Music
    (mkArr "lidarr" { port = 8686; })

    # Books - disabled because it's pretty shit; will look at alternatives
    # (mkArr "readarr" {
    #   port = 8787;
    #   image = "lscr.io/linuxserver/readarr:develop";
    # })

    # Subtitles
    (mkArr "bazarr" { port = 6767; })

    # Indexer aggregation
    (mkArr "prowlarr" {
      port = 9696;
      needsMedia = false;
    })

    # Managing media requests
    (mkArr "overseerr" {
      image = "sctx/overseerr:latest";
      port = 5055;
      needsMedia = false;
      configMount = "/app/config";
      funnel = true;
    })

    # Reliably unpacking media
    (mkArr "unpackerr" {
      image = "ghcr.io/unpackerr/unpackerr:latest";
    })

    # Subscribe to private tracker IRC announce channels and auto-download certain torrents
    (mkArr "autobrr" {
      image = "ghcr.io/autobrr/autobrr:latest";
      port = 7474;
      needsMedia = false;
    })

    # Collect statistics about what is getting watched in Plex, so that I can
    # remove things that aren't being watched if I need to free up space.
    (mkArr "tautulli" {
      image = "ghcr.io/tautulli/tautulli:latest";
      port = 8181;
      needsMedia = false;
    })

    (mkArr "maintainerr" {
      image = "ghcr.io/jorenn92/maintainerr:latest";
      port = 6246;
      needsMedia = false;
      configMount = "/opt/data";
      forceUser = "1000:1000";
    })

    (mkArr "recyclarr" {
      image = "ghcr.io/recyclarr/recyclarr:latest";
      needsMedia = false;
      forceUser = "1000:1000";
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
