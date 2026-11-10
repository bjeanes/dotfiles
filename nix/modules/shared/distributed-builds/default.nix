# The client half of ../../nixos/distributed-builds, which nix-darwin hosts can use too.
{
  config,
  flake,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.distributed-builds;

  inherit (flake.lib) hosts;

  # Anything in the registry carrying a host key is one of this flake's NixOS
  # machines.
  peers = lib.filterAttrs (_: host: host ? hostKey) hosts;

  selfName = lib.toLower config.networking.hostName;
  self = hosts.${selfName} or { };

  remotes = lib.filterAttrs (name: host: name != selfName && host ? builder) peers;

  nativePlatforms = {
    x86_64-linux = [ "i686-linux" ];
  };

  allAddressesOf =
    host:
    lib.unique (
      (host.addresses or [ ])
      ++ (builtins.filter (a: a != null) (
        map (k: host.${k} or null) [
          "ts"
          "zt"
          "lan"
        ]
      ))
    );

  # Tailscale when both ends are on the tailnet
  addressOf =
    host: if self ? ts && host ? ts then host.ts else host.lan or (builtins.head host.addresses);
in
{
  options.distributed-builds = {
    enable = lib.mkEnableOption "using the other NixOS machines as remote builders" // {
      default = peers ? ${selfName} || cfg.client;
    };

    # Every Mac, so that its linux-builder VM (../../darwin/nix) needn't build
    # x86_64-linux under Rosetta.
    client = lib.mkEnableOption "handing this host's builds to the machines that serve them" // {
      default = self.buildClient or pkgs.stdenv.hostPlatform.isDarwin;
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "nixremote";
      description = ''
        Unprivileged account the other machines log in as to submit builds. It
        has to be in nix's `trusted-users` -- a remote build means uploading
        unsigned derivation inputs -- so it is deliberately its own user rather
        than root or me.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # Root is the one doing the connecting (the nix daemon and comin both run
      # as root), so pin the peers' host keys system-wide: an unattended build
      # has nobody around to answer a host-key prompt.
      programs.ssh.knownHosts = lib.mapAttrs (name: host: {
        hostNames = [ name ] ++ (host.aliases or [ ]) ++ allAddressesOf host;
        publicKey = host.hostKey;
      }) peers;
    })

    (lib.mkIf (cfg.enable && cfg.client) {
      nix = {
        distributedBuilds = remotes != { };

        buildMachines = lib.mapAttrsToList (_: host: {
          hostName = addressOf host;
          sshUser = cfg.user;

          # No dedicated build key: the host key we already publish is the
          # identity, and it is root-readable only.
          sshKey = "/etc/ssh/ssh_host_ed25519_key";

          # ssh-ng rather than the legacy protocol: it speaks to the remote
          # nix-daemon, so the builder's own sandboxing and settings apply.
          protocol = "ssh-ng";

          systems = [ host.builder.system ] ++ (nativePlatforms.${host.builder.system} or [ ]);

          inherit (host.builder) maxJobs speedFactor;

          supportedFeatures =
            host.builder.supportedFeatures or [
              "big-parallel"
              "kvm"
              "nixos-test"
              "benchmark"
            ];
        }) remotes;

        # Let the builder pull from the binary caches itself rather than
        # having the (possibly much slower) client fetch and forward.
        settings.builders-use-substitutes = true;
      };
    })
  ];
}
