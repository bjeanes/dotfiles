# qBittorrent and any supporting services
{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
let
  svc = "qbittorrent";
  coalesce = val: default: if (val == null) then default else val;
in
{
  options.homelab.services.${svc} = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable ${svc}";
    };

    image = lib.mkOption {
      default = "lscr.io/linuxserver/qbittorrent:4.6.7";
      type = lib.types.str;
      description = "OCI image for ${svc}";
    };

    torrentPort = lib.mkOption {
      default = 60265;
      type = lib.types.port;
      description = "Port used by BitTorrent protocol";
    };

    webUiPort = lib.mkOption {
      default = 8080;
      type = lib.types.port;
      description = "Port used for ${svc}'s Web UI";
    };

    configDir = lib.mkOption {
      default = "/var/lib/homelab/${svc}";
      example = "/var/lib/homelab/${svc}";
      type = lib.types.str;
      description = "Location to store service config";
    };

    timeZone = lib.mkOption {
      default = config.homelab.timeZone;
      type = lib.types.str;
      description = "Time zone for ${svc}";
    };

    user = lib.mkOption {
      default = coalesce config.homelab.user svc;
      type = lib.types.str;
      description = ''
        User to run ${svc} service as
      '';
    };

    group = lib.mkOption {
      default = config.homelab.group;
      type = lib.types.str;
      description = ''
        Group to run the ${svc} service as
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
      myLib = lib.${namespace};
      cfg = config.homelab.services.${svc};
      svcName = myLib.containerSvcName config svc;
      setEnvFromCommandsForContainer = myLib.setEnvFromCommandsForContainer config;
      setEnvFromFilesForContainer = myLib.setEnvFromFilesForContainer config;
      secrets = config.age.secrets;
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          users.users = {
            "${cfg.user}" = {
              isSystemUser = true;
              group = cfg.group;
            };
          };
          users.groups.${cfg.group} = { };

          systemd.services.${myLib.containerSvcName config "${svc}-vpn"} = {
            aliases = [ "${svc}-vpn.service" ];
          };

          systemd.services.${myLib.containerSvcName config "${svc}-tailscale"} = {
            partOf = [ "${svc}.service" ];
          };

          systemd.services.${svcName} = {
            aliases = [ "${svc}.service" ];
            requires = [ "mnt-nfs-tempnas-media.mount" ];
            after = [ "mnt-nfs-tempnas-media.mount" ];
            upheldBy = [
              "${svc}.service"
              "mnt-nfs-tempnas-media.mount"
            ];
            serviceConfig = {
              TimeoutStopSec = lib.mkForce "2h";
            };
          };

          systemd.tmpfiles.rules =
            let
              inherit (cfg) user group;
            in
            [
              # Ensure config directory exists, owned by user
              "d ${cfg.configDir}    0775 ${user} ${group} - -"
              "d ${cfg.configDir}/ts 0775 ${user} ${group} - -"

              # Ensure directory and contents belong to specified owner and group
              "Z ${cfg.configDir} - ${user} ${group} - -"
            ];

          virtualisation.oci-containers = {
            containers = {
              "${svc}-vpn" = {
                image = "ghcr.io/qdm12/gluetun:v3";
                extraOptions = [
                  "--cap-add=net_admin"
                  "--pull=always"
                  "--device=/dev/net/tun:/dev/net/tun"
                ];
                environment = {
                  TZ = cfg.timeZone;
                  VPN_SERVICE_PROVIDER = "airvpn";
                  VPN_TYPE = "wireguard";
                  SERVER_REGIONS = "Oceania";
                  FIREWALL_VPN_INPUT_PORTS = toString cfg.torrentPort;
                  FIREWALL_INPUT_PORTS = toString cfg.webUiPort;
                  FIREWALL_OUTBOUND_SUBNETS = "10.10.10.0/24";
                };
                volumes = [
                  # "${secrets.wg-conf.path}/run/secrets/wireguard_conf"
                  "${secrets.wg-private-key.path}:/run/secrets/wireguard_private_key"
                  "${secrets.wg-preshared-key.path}:/run/secrets/wireguard_preshared_key"
                  "${secrets.wg-addresses.path}:/run/secrets/wireguard_addresses"
                ];
              };

              ${svc} = {
                image = cfg.image;
                autoStart = true;
                dependsOn = [ "${svc}-vpn" ];
                volumes = [
                  "${cfg.configDir}:/config"
                  "/mnt/nfs/tempnas/media:/data"
                ];
                extraOptions = [
                  "--pull=always"
                  "--network=container:${svc}-vpn"
                  # "--stop-timeout=-1" # -1 is Docker only, but we are running Podman
                  "--stop-timeout=7200" # 2 hours
                ];
                environment = {
                  TORRENTING_PORT = toString cfg.torrentPort;
                  TZ = cfg.timeZone;
                  UMASK = "002";
                  DOCKER_MODS = "linuxserver/mods:universal-stdout-logs|ghcr.io/vuetorrent/vuetorrent-lsio-mod:latest";
                  LOGS_TO_STDOUT = "/config/qBittorrent/logs/qbittorrent.log";
                };
              };
            };
          };
        }

        (lib.mkIf cfg.backupToNAS {
          systemd.services."backup-${svc}-to-NAS" = {
            requires = [ "mnt-nfs-tempnas-docker.mount" ];
            after = [ "mnt-nfs-tempnas-docker.mount" ];
            startAt = "*-*-* 02:00:00 ${cfg.timeZone}";
            serviceConfig = {
              Type = "oneshot";
            };
            script = ''
              set -eu
              ${pkgs.util-linux}/bin/flock /tmp/backup-to-NAS.lock \
                ${pkgs.rsync}/bin/rsync -avuP --no-o --no-g ${lib.escapeShellArg cfg.configDir}/* /mnt/nfs/tempnas/docker/media/${svc}/
            '';
          };
        })

        (myLib.mkTailscaleContainer pkgs config "${svc}-tailscale" {
          hostname = "qb";
          serve = {
            TCP."443".HTTPS = true;
            Web."\${TS_CERT_DOMAIN}:443".Handlers."/".Proxy =
              "http://localhost:${builtins.toString cfg.webUiPort}";
          };
          container = {
            extraOptions = [ "--network=container:${svc}-vpn" ];
            dependsOn = [
              "${svc}-vpn"
              svc
            ];
          };
        })

        # Nix expressions give us no way to derive the UID from a user at
        # evaluation time, so this delays resolution of user/group names
        # to UID/GID at service start time, by modifying the
        # systemd.service record for the docker container.
        (setEnvFromCommandsForContainer svc {
          PUID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
          PGID = "${pkgs.getent}/bin/getent group ${cfg.group} | cut -d: -f3";
        })
      ]
    );
}
