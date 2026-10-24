# qBittorrent and any supporting services
{
  config,
  lib,
  flake,
  pkgs,
  ...
}:
let
  svc = "qbittorrent";
in
{
  options.homelab.services.${svc} =
    flake.lib.mkHomelabServiceOptions config svc {
      image = "lscr.io/linuxserver/qbittorrent:latest";
      hostName = "qb";
      exposeAs = "sidecar";
      withUser = true;
    }
    // {
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
    };

  config =
    let
      myLib = flake.lib;
      cfg = config.homelab.services.${svc};
      secrets = config.age.secrets;

      inherit (config.virtualisation.quadlet) pods;

      podName = "${svc}-pod";
      vpnName = "${svc}-vpn";
      mediaMount = "mnt-nfs-nas-media.mount";

      # Seeding torrents get the time they need to stop cleanly
      stopTimeout = 7200;
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

          systemd.tmpfiles.rules =
            let
              inherit (cfg) user group;
            in
            [
              # Ensure config directory exists, owned by user
              "d ${cfg.configDir}    0775 ${user} ${group} - -"

              # Ensure directory and contents belong to specified owner and group
              "Z ${cfg.configDir} - ${user} ${group} - -"
            ];

          virtualisation.quadlet = {
            # Everything in the pod shares gluetun's network namespace, so
            # all of it goes out through the VPN
            pods.${podName}.podConfig = { inherit stopTimeout; };

            containers = {
              ${vpnName} = {
                autoStart = true;
                containerConfig = {
                  pod = pods.${podName}.ref;
                  image = "ghcr.io/qdm12/gluetun:v3";
                  pull = "always";
                  addCapabilities = [ "NET_ADMIN" ];
                  devices = [ "/dev/net/tun:/dev/net/tun" ];
                  environments = {
                    TZ = cfg.timeZone;
                    VPN_SERVICE_PROVIDER = "airvpn";
                    VPN_TYPE = "wireguard";
                    SERVER_REGIONS = "Oceania";
                    FIREWALL_VPN_INPUT_PORTS = toString cfg.torrentPort;
                    FIREWALL_INPUT_PORTS = toString cfg.webUiPort;
                    FIREWALL_OUTBOUND_SUBNETS = myLib.lanSubnet;
                  };
                  volumes = [
                    "${secrets.wg-private-key.path}:/run/secrets/wireguard_private_key"
                    "${secrets.wg-preshared-key.path}:/run/secrets/wireguard_preshared_key"
                    "${secrets.wg-addresses.path}:/run/secrets/wireguard_addresses"
                  ];
                };
              };

              ${svc} = {
                autoStart = true;
                containerConfig = {
                  pod = pods.${podName}.ref;
                  image = cfg.image;
                  pull = "always";
                  inherit stopTimeout;
                  volumes = [
                    "${cfg.configDir}:/config"
                    "/mnt/nfs/nas/media:/data"
                  ];
                  environments = {
                    TORRENTING_PORT = toString cfg.torrentPort;
                    TZ = cfg.timeZone;
                    UMASK = "002";
                    DOCKER_MODS = "linuxserver/mods:universal-stdout-logs|ghcr.io/vuetorrent/vuetorrent-lsio-mod:latest";
                    LOGS_TO_STDOUT = "/config/qBittorrent/logs/qbittorrent.log";
                  };
                };
                unitConfig = {
                  After = [
                    "${vpnName}.service"
                    mediaMount
                  ];
                  Requires = [ "${vpnName}.service" ];
                  BindsTo = [ mediaMount ];
                };
                serviceConfig.TimeoutStopSec = "${toString stopTimeout}s";
              };
            };
          };
        }

        # The sidecar's tailscaled also has to wait for the tunnel
        (lib.mkIf (cfg.tailscale.exposeAs == "sidecar") {
          virtualisation.quadlet.containers."${svc}-tailscale".unitConfig = {
            After = [ "${vpnName}.service" ];
            Requires = [ "${vpnName}.service" ];
          };
        })

        (lib.mkIf cfg.backupToNAS (
          myLib.buildBackupScriptForDir pkgs svc cfg.configDir { inherit (cfg) timeZone; }
        ))

        (myLib.mkTailscaleQuadletExposure pkgs config svc {
          inherit podName;
          https = cfg.webUiPort;
        })

        # Nix expressions give us no way to derive the UID from a user at
        # evaluation time, so these resolve at service start.
        (myLib.mkQuadletDynamicEnvironment pkgs config {
          containerName = svc;
          variables = {
            PUID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
            PGID = "${pkgs.getent}/bin/getent group ${cfg.group} | cut -d: -f3";
          };
        })
      ]
    );
}
