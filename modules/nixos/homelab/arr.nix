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
      port,
      module ? (_: { }),
      ...
    }:
    let
      svcName = myLib.containerSvcName config name;
    in
    {
      imports = [
        (
          args:
          let
            submodule = (module args);
          in
          {
            options.homelab.services.${name} = submodule.options or { };
            config = submodule.config or { };
          }
        )
      ];

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
                    volumes = [ "${cfg.configDir}:/config" ];
                    environment = {
                      TZ = cfg.timeZone;
                      UMASK = "002";
                    };
                  };
                };
              };
            }
            # Nix expressions give us no way to derive the UID from a user at
            # evaluation time, so this delays resolution of user/group names
            # to UID/GID at service start time, by modifying the
            # systemd.service record for the docker container.
            (setEnvFromCommandsForContainer name {
              PUID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
              PGID = "${pkgs.getent}/bin/getent group ${cfg.group} | cut -d: -f3";
            })
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

                ${tsName} =
                  let
                    serve = pkgs.writers.writeJSON "ts-serve.json" {
                      TCP."443".HTTPS = true;
                      Web."${name}.${tsnet}:443".Handlers."/".Proxy = "http://127.0.0.1:${builtins.toString port}";
                    };
                  in
                  {
                    image = "tailscale/tailscale:latest";
                    hostname = name;
                    volumes = [
                      "${serve}:${serve}"
                    ];
                    extraOptions = [
                      "--cap-add=net_admin"
                      "--cap-add=sys_module"
                    ];
                    environment = {
                      TS_SERVE_CONFIG = "${serve}";
                      TS_EXTRA_ARGS = "--advertise-tags=tag:home,tag:service";
                      TS_HOSTNAME = name;
                    };
                  };
              };
            }))
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

    # # Managing media requests
    # (mkArr "overseer" { port = 5055; needsMedia = false; })

    # Reliably unpacking media
    (mkArr "unpackerr" {
      image = "ghcr.io/unpackerr/unpackerr:latest";
      port = 5656;
      module =
        { config, lib, ... }:
        let
          svcs = [
            "sonarr"
            "radarr"
            "lidarr"
            # "readarr"
          ];
          cfg = config.homelab.services.unpackerr;
        in
        {
          options = lib.mergeAttrsList (
            lib.map (arr: {
              ${arr} = {
                enable = lib.mkOption {
                  default = config.homelab.services.${arr}.enable;
                  type = lib.types.bool;
                  description = "Enable unpackerr on ${arr}";
                };

                url = lib.mkOption {
                  default =
                    if config.homelab.services.${arr}.tailscale.enable then "https://${arr}.${tsnet}" else null;
                  type = lib.types.str;
                  description = "URL for Unpacker to use for ${arr}";
                };

                apiKeyFile = lib.mkOption {
                  default = config.age.secrets."${arr}-api-key".path;
                  type = lib.types.str;
                  description = "File with contents for Unpacker to use as API key for ${arr}";
                };
              };
            }) svcs
          );

          config = lib.mkIf cfg.enable (
            lib.mkMerge (
              lib.map (
                arr:

                let
                  cfg = config.homelab.services.unpackerr.${arr};
                in
                lib.mkIf cfg.enable (
                  lib.mkMerge [
                    {
                      virtualisation.oci-containers.containers.unpackerr.environment = {
                        "UN_${lib.toUpper arr}_0_URL" = cfg.url; # TODO: make this not coupled to Tailscale
                      };
                    }
                    (setEnvFromFilesForContainer "unpackerr" {
                      "UN_${lib.toUpper arr}_0_API_KEY" = cfg.apiKeyFile;
                    })
                  ]
                )
              ) svcs
            )
          );
        };
    })

    # Subscribe to private tracker IRC announce channels and auto-download certain torrents
    (mkArr "autobrr" {
      image = "ghcr.io/autobrr/autobrr:latest";
      port = 7474;
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
