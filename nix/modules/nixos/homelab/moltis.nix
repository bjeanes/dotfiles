{
  config,
  lib,
  flake,
  inputs,
  perSystem,
  ...
}:
let
  svc = "moltis";
  cfg = config.homelab.services.${svc};

  tap = "vm-${svc}";
  mac = "02:00:00:00:00:01";
  hostAddress = "10.231.0.1";
  guestAddress = "10.231.0.2";
  port = 13131;

  # Keep other secrets out of here. The guest can read everything in it.
  secretsDir = "/run/microvm-${svc}-secrets";

  # Environment variable in the guest => agenix secret
  secrets = {
    OPENROUTER_API_KEY = "openrouter-api-key";
    # Lets Moltis unseal its vault at boot, before it loads stored channels
    MOLTIS_VAULT_AUTO_UNSEAL_KEY = "moltis-vault-recovery-key";
  };

  blockedRanges = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "100.64.0.0/10" # tailnet
    "169.254.0.0/16"
  ];

  iptables = "iptables -w";
  ip6tables = "ip6tables -w";
in
{
  imports = [ inputs.microvm.nixosModules.host ];

  options.homelab.services.${svc} = {
    enable = lib.mkEnableOption "Moltis, in a microVM of its own";

    hostName = lib.mkOption {
      default = svc;
      type = lib.types.str;
      description = "Tailscale Service name to expose ${svc} as";
    };

    externalInterface = lib.mkOption {
      default = "eno1";
      type = lib.types.str;
      description = "Interface the guest's traffic is NATed out of";
    };

    vcpu = lib.mkOption {
      default = 2;
      type = lib.types.ints.positive;
    };

    memoryMB = lib.mkOption {
      default = 3072;
      type = lib.types.ints.positive;
    };

    stateSizeMB = lib.mkOption {
      default = 20480;
      type = lib.types.ints.positive;
      description = "Size of the guest's /var/lib, which also holds the sandbox's container images";
    };
  };

  config = lib.mkMerge [
    { microvm.host.enable = cfg.enable; }

    (lib.mkIf cfg.enable {
      age.secrets = lib.mapAttrs' (
        _: name:
        lib.nameValuePair name {
          path = "${secretsDir}/${name}";
          symlink = false;
        }
      ) secrets;

      microvm.vms.${svc} = {
        specialArgs = { inherit perSystem; };

        config = {
          imports = [ flake.nixosModules.moltis ];

          system.stateVersion = "26.11";
          networking.hostName = svc;

          microvm = {
            hypervisor = "cloud-hypervisor";
            inherit (cfg) vcpu;
            mem = cfg.memoryMB;

            interfaces = [
              {
                type = "tap";
                id = tap;
                inherit mac;
              }
            ];

            shares = [
              {
                proto = "virtiofs";
                tag = "ro-store";
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
                readOnly = true;
              }
              {
                proto = "virtiofs";
                tag = "secrets";
                source = secretsDir;
                mountPoint = "/run/host-secrets";
                readOnly = true;
              }
              {
                # journalctl --directory /var/lib/microvms/moltis/journal
                proto = "virtiofs";
                tag = "journal";
                source = "journal";
                mountPoint = "/var/log/journal";
              }
            ];

            volumes = [
              {
                image = "var-lib.img";
                mountPoint = "/var/lib";
                size = cfg.stateSizeMB;
              }
            ];

            # sudo microvm -s moltis -- -i /etc/ssh/ssh_host_ed25519_key
            vsock = {
              cid = 3;
              ssh.enable = true;
            };
          };

          # Only over vsock, from the host
          services.openssh.openFirewall = false;
          users.users.root.openssh.authorizedKeys.keys = [
            flake.lib.hosts.${lib.toLower config.networking.hostName}.hostKey
          ];

          networking.useNetworkd = true;
          systemd.network.networks."10-uplink" = {
            matchConfig.MACAddress = mac;
            address = [ "${guestAddress}/24" ];
            routes = [ { Gateway = hostAddress; } ];
            dns = [
              "9.9.9.9"
              "149.112.112.112"
            ];
          };

          services.moltis = {
            enable = true;
            bind = "0.0.0.0";
            inherit port;
            openFirewall = true;
            credentials = lib.mapAttrs (_: name: "/run/host-secrets/${name}") secrets;
            environment = {
              MOLTIS_BEHIND_PROXY = "true";
              MOLTIS_EXTERNAL_URL = "https://${cfg.hostName}.${config.homelab.tailscale.tailnet}";
            };
          };
        };
      };

      networking.networkmanager.unmanaged = [ "interface-name:${tap}" ];
      networking.interfaces.${tap}.ipv4.addresses = [
        {
          address = hostAddress;
          prefixLength = 24;
        }
      ];

      networking.nat = {
        enable = true;
        internalInterfaces = [ tap ];
        inherit (cfg) externalInterface;
      };

      # The guest may only reach the internet, and only over IPv4. The LAN, the
      # tailnet and this host are blocked, except for replies to connections the
      # host opens, such as tailscaled proxying svc:moltis to it.
      networking.firewall.extraCommands = ''
        ${iptables} -N ${svc}-in 2>/dev/null || ${iptables} -F ${svc}-in
        ${iptables} -A ${svc}-in -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
        ${iptables} -A ${svc}-in -j DROP
        ${iptables} -C INPUT -i ${tap} -j ${svc}-in 2>/dev/null || ${iptables} -I INPUT -i ${tap} -j ${svc}-in

        ${iptables} -N ${svc}-fwd 2>/dev/null || ${iptables} -F ${svc}-fwd
        ${lib.concatMapStrings (range: ''
          ${iptables} -A ${svc}-fwd -d ${range} -j DROP
        '') blockedRanges}
        ${iptables} -C FORWARD -i ${tap} -j ${svc}-fwd 2>/dev/null || ${iptables} -I FORWARD -i ${tap} -j ${svc}-fwd

        ${ip6tables} -C INPUT -i ${tap} -j DROP 2>/dev/null || ${ip6tables} -I INPUT -i ${tap} -j DROP
        ${ip6tables} -C FORWARD -i ${tap} -j DROP 2>/dev/null || ${ip6tables} -I FORWARD -i ${tap} -j DROP
      '';

      networking.firewall.extraStopCommands = ''
        ${iptables} -D INPUT -i ${tap} -j ${svc}-in 2>/dev/null || true
        ${iptables} -D FORWARD -i ${tap} -j ${svc}-fwd 2>/dev/null || true
        ${ip6tables} -D INPUT -i ${tap} -j DROP 2>/dev/null || true
        ${ip6tables} -D FORWARD -i ${tap} -j DROP 2>/dev/null || true
      '';

      homelab.tailscale.serve.services.${cfg.hostName}.https = "http://${guestAddress}:${toString port}";
    })
  ];
}
