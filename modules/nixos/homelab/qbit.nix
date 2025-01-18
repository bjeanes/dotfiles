# qBittorrent and any supporting services
{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
let
  coalesce = val: default: if (val == null) then default else val;
in
{
  options.homelab.services.qbittorrent = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable qbittorrent";
    };

    image = lib.mkOption {
      default = "lscr.io/linuxserver/qbittorrent:4.6.7";
      type = lib.types.str;
      description = "OCI image for qBittorrent";
    };

    torrentPort = lib.mkOption {
      default = 60265;
      type = lib.types.port;
      description = "Port used by BitTorrent protocol";
    };

    webUiPort = lib.mkOption {
      default = 8080;
      type = lib.types.port;
      description = "Port used for qBittorrent's Web UI";
    };

    configDir = lib.mkOption {
      default = "/var/lib/homelab/qbittorrent";
      example = "/var/lib/homelab/qbittorrent";
      type = lib.types.str;
      description = "Location to store service config";
    };

    timeZone = lib.mkOption {
      default = config.homelab.timeZone;
      type = lib.types.str;
      description = "Time zone for qBittorrent";
    };

    user = lib.mkOption {
      default = coalesce config.homelab.user "qbittorrent";
      type = lib.types.str;
      description = ''
        User to run qbittorrent service as
      '';
    };

    group = lib.mkOption {
      default = config.homelab.group;
      type = lib.types.str;
      description = ''
        Group to run the qbittorrent service as
      '';
    };

    backupToNAS = lib.mkOption {
      default = false; # TODO until confirmed working correctly
      type = lib.types.bool;
      description = "Back up configDir to legacy location on NAS";
    };
  };

  config =
    let
      myLib = lib.${namespace};
      cfg = config.homelab.services.qbittorrent;
      svcName = myLib.containerSvcName config "qbittorrent";
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

          systemd.services.${myLib.containerSvcName config "qbittorrent-vpn"} = {
            aliases = [ "qbittorrent-vpn.service" ];
          };

          systemd.services.${myLib.containerSvcName config "qbittorrent-tailscale"} = {
            aliases = [ "qbittorrent-tailscale.service" ];
            partOf = [ "qbittorrent.service" ];
          };

          systemd.services.${svcName} = {
            aliases = [ "qbittorrent.service" ];
            requires = [ "nas-media.automount" ];
            after = [ "nas-media.automount" ];
            upheldBy = [
              "qbittorrent-vpn.service"
              "nas-media.automount"
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
              qbittorrent-vpn = {
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

              qbittorrent = {
                image = cfg.image;
                autoStart = true;
                dependsOn = [ "qbittorrent-vpn" ];
                volumes = [
                  "${cfg.configDir}:/config"
                  "/nas/media:/data"
                ];
                extraOptions = [
                  "--pull=always"
                  "--network=container:qbittorrent-vpn"
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

              qbittorrent-tailscale =
                let
                  serve = pkgs.writers.writeJSON "ts-serve.json" ({
                    TCP."443".HTTPS = true;
                    Web."\${TS_CERT_DOMAIN}:443".Handlers."/".Proxy =
                      "http://localhost:${builtins.toString cfg.webUiPort}";
                  });
                in
                {
                  image = "tailscale/tailscale:latest";
                  dependsOn = [
                    "qbittorrent-vpn"
                    "qbittorrent"
                  ];
                  extraOptions = [
                    "--cap-add=net_admin"
                    "--cap-add=sys_module"
                    "--network=container:qbittorrent-vpn"
                    #"--pull=always"
                  ];
                  volumes = [
                    "${serve}:${serve}"
                    "${cfg.configDir}/ts:/var/lib/tailscale"
                  ];
                  environment = {
                    TS_SERVE_CONFIG = "${serve}";
                    TS_EXTRA_ARGS = "--advertise-tags=tag:home,tag:server --accept-dns=false";
                    TS_HOSTNAME = "qb";
                    TS_STATE_DIR = "/var/lib/tailscale";
                  };
                };
            };
          };
        }

        (setEnvFromFilesForContainer "qbittorrent-tailscale" {
          TS_AUTHKEY = config.age.secrets.tailscale-auth-server.path;
        })

        # Nix expressions give us no way to derive the UID from a user at
        # evaluation time, so this delays resolution of user/group names
        # to UID/GID at service start time, by modifying the
        # systemd.service record for the docker container.
        (setEnvFromCommandsForContainer "qbittorrent" {
          PUID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
          PGID = "${pkgs.getent}/bin/getent group ${cfg.group} | cut -d: -f3";
        })
      ]
    );
}
