{
  lib,
  config,
  pkgs,
  ...
}:
let
  coalesce = val: default: if (val == null) then default else val;
  svcName = name: "${config.virtualisation.oci-containers.backend}-${name}";

  # Some images expect secrets as ENV vars, but
  # `virtualisation.oci-containers.containers.*` does not have API surface area
  # for doing this. To avoid overridng `entrypoint` on arbitrary images (which
  # may depend on their entrypoint), this takes advantage of the way that NixOS
  # creates systemd services for each Docker container, and modifies the start
  # script and the container definition to allow setting the environment
  # variable to a value from a file, before allowing the container to inherit
  # it.
  setEnvFromFilesForContainer =
    name: vars: with lib; {
      # Add `-e VAR` to add var to container from context environment
      virtualisation.oci-containers.containers.${name}.extraOptions = map (n: "-e=${escapeShellArg n}") (
        builtins.attrNames vars
      );

      systemd.services.${svcName name}.script = mkBefore (
        concatStringsSep " \\\n  " (
          mapAttrsToList (k: v: ''export ${escapeShellArg k}="$(cat ${escapeShellArg v})"'') vars
        )
      );
    };
  mkArr =
    name:
    {
      needsMedia ? true,
      port,
      ...
    }:
    {
      options.homelab.services.${name} = {
        enable = lib.mkOption {
          default = false;
          type = lib.types.bool;
          description = "Enable ${name}";
        };

        tailscale = {
          enable = lib.mkOption {
            default = config.homelab.tailscale.enable;
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
          default = "lscr.io/linuxserver/${name}:latest";
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
          tsnet = "griffin-climb.ts.net";
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

              systemd.services."${svcName name}".aliases = [ "${name}.service" ];

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
                      PUID = cfg.user;
                      GUID = cfg.group;
                      UMASK = "002";
                    };
                  };
                };
              };
            }
            (lib.optionalAttrs needsMedia {
              virtualisation.oci-containers.containers.${name}.volumes = [
                "/nas/media:/data"
              ];
              systemd.services = {
                "${svcName name}" = {
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

    # Subtitles
    (mkArr "bazarr" { port = 6767; })

    # Indexer aggregation
    (mkArr "prowlarr" {
      port = 9696;
      needsMedia = false;
    })

    # # Managing media requests
    # (mkArr "overseer" { port = 5055; needsMedia = false; })

    # # Reliably unpacking media
    # (mkArr "unpackerr" { port = 5656; execAsUser = true; })

    # Subscribe to private tracker IRC announce channels and auto-download certain torrents
    (mkArr "autobrr" {
      port = 7474;
      needsMedia = false;
    })
  ];
}
