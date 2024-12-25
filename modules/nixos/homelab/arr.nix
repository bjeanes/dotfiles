{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  tsnet = "griffin-climb.ts.net";
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
      runsAsUser ? false,
      configMount ? "/config",
      funnel ? false,
      ...
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

        user = lib.mkOption {
          default = coalesce config.homelab.user name;
          type = lib.types.str;
          description = ''
            User to run ${name} services as
          '';
        };

        group = lib.mkOption {
          default = config.homelab.group;
          type = lib.types.str;
          description = ''
            Group to run the homelab services as
          '';
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
      };

      config =
        let
          cfg = config.homelab.services.${name};
          tsName = "${name}-tailscale";
        in
        lib.mkIf cfg.enable (
          lib.mkMerge [
            {
              # https://www.man7.org/linux/man-pages/man5/tmpfiles.d.5.html#SYNOPSIS
              systemd.tmpfiles.rules =
                lib.concatMap
                  (dir: [
                    # Ensure config directory exists, owned by user
                    "d ${dir} 0775 ${cfg.user} ${cfg.group} - -"

                    # Ensure directory and contents belong to specified owner and group
                    "Z ${dir} - ${cfg.user} ${cfg.group} - -"
                  ])
                  [
                    cfg.configDir
                  ];

              systemd.services.${svcName}.aliases = [ "${name}.service" ];

              users.users = {
                "${cfg.user}" = {
                  isSystemUser = true;
                  group = config.homelab.services.${name}.group;
                };
              };
              users.groups.${cfg.group} = { };

              virtualisation.oci-containers = {
                containers = {
                  ${name} = {
                    image = cfg.image;
                    autoStart = true;
                    volumes = [ "${cfg.configDir}:${configMount}" ];
                    environment = {
                      TZ = cfg.timeZone;
                      UMASK = "002";
                    };
                  };
                };
              };
            }
            (lib.mkIf runsAsUser {
              virtualisation.oci-containers.containers.${name} = {
                # FIXME: this causes:
                #           docker: Error response from daemon: unable to find user overseer: no matching entries in passwd file.
                #        even though:
                #           ❯ getent passwd overseerr
                #           overseerr:x:985:992::/var/empty:/run/current-system/sw/bin/nologin
                #        I guess this requires it to be in /etc/passwd _in_ the container...
                #        I might need to do similar thing as `setEnvFromCommandsForContainer` to set the --user arg directly as UID/GID?
                #        alt: switch to podman which has `--hostuser` option that might allow for this?
                # user = "${cfg.user}:${cfg.group}";
              };
            })
            (lib.mkIf (!runsAsUser) (
              # Nix expressions give us no way to derive the UID from a user at
              # evaluation time, so this delays resolution of user/group names
              # to UID/GID at service start time, by modifying the
              # systemd.service record for the docker container.
              setEnvFromCommandsForContainer name {
                PUID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
                PGID = "${pkgs.getent}/bin/getent group ${cfg.group} | cut -d: -f3";
              }
            ))
            (lib.optionalAttrs needsMedia {
              virtualisation.oci-containers.containers.${name}.volumes = [
                "/nas/media:/data"
              ];
              systemd.services = {
                ${svcName} = {
                  requires = lib.optionals needsMedia [ "nas-media.automount" ];
                };
              };
            })
            (lib.mkIf cfg.backupToNAS {
              systemd.services."backup-${name}-to-NAS" = {
                requires = [ "nas-docker.automount" ];
                startAt = "*-*-* 02:00:00 ${cfg.timeZone}";
                serviceConfig = {
                  Type = "oneshot";
                };
                script = ''
                  set -eu
                  ${pkgs.util-linux}/bin/flock /tmp/backup-to-NAS.lock \
                    ${pkgs.rsync}/bin/rsync -avuP --no-o --no-g ${lib.escapeShellArg cfg.configDir}/* /nas/docker/media/${name}/
                '';
              };
            })
            (lib.mkIf cfg.tailscale.enable ({
              virtualisation.oci-containers.containers = {
                # Set up main service container to use and depend on the network container for Tailscale
                ${name} = {
                  extraOptions = lib.optionals cfg.tailscale.enable [
                    "--network=container:${tsName}"
                  ];
                  dependsOn = [ tsName ];
                };

                ${tsName} = {
                  image = "tailscale/tailscale:latest";
                  hostname = name;
                  extraOptions = [
                    "--cap-add=net_admin"
                    "--cap-add=sys_module"
                  ];
                  environment = {
                    TS_EXTRA_ARGS = "--advertise-tags=tag:home,tag:service";
                    TS_HOSTNAME = name;
                  };
                };
              };
            }))
            (lib.mkIf (cfg.tailscale.enable && port != null) {
              virtualisation.oci-containers.containers = {
                ${tsName} =
                  let
                    endpoint = "${name}.${tsnet}:443";
                    serve = pkgs.writers.writeJSON "ts-serve.json" (
                      {
                        TCP."443".HTTPS = true;
                        Web.${endpoint}.Handlers."/".Proxy = "http://127.0.0.1:${builtins.toString port}";
                      }
                      // (lib.optionalAttrs funnel {
                        AllowFunnel.${endpoint} = true;
                      })
                    );
                  in
                  {
                    volumes = [
                      "${serve}:${serve}"
                    ];
                    environment = {
                      TS_SERVE_CONFIG = "${serve}";
                    };
                  };
              };
            })
            (lib.mkIf cfg.tailscale.enable (
              setEnvFromFilesForContainer tsName {
                TS_AUTHKEY = config.age.secrets.tailscale-auth-service.path;
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
      # runsAsUser = true;
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

    (mkArr "tautulli" {
      image = "ghcr.io/tautulli/tautulli";
      port = 8181;
      needsMedia = false;
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
