# A build mesh across the NixOS machines in this flake: every host offers its spare cores to the others, so whoever
# kicks off a rebuild gets the whole fleet's CPUs rather than just the one in front of it. Tulgey, a fanless 2-core wall
# panel, is the motivating case as it has kernel patches to compile.
#
# Authentication reuses each machine's SSH *host* key as its client identity.  Those public keys are already in the
# registry (agenix needs them anyway).
{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
let
  cfg = config.distributed-builds;

  inherit (lib.${namespace}) hosts;

  # Anything in the registry carrying a host key is one of this flake's NixOS
  # machines.
  peers = lib.filterAttrs (_: host: host ? hostKey) hosts;

  selfName = lib.toLower config.networking.hostName;
  self = peers.${selfName} or { };

  remotes = lib.filterAttrs (name: host: name != selfName && host ? builder) peers;

  # Tailscale when both ends are on the tailnet
  addressOf =
    host: if self ? ts && host ? ts then host.ts else host.lan or (builtins.head host.addresses);
in
{
  options.distributed-builds = {
    enable = lib.mkEnableOption "using the other NixOS machines as remote builders" // {
      default = peers ? ${selfName};
    };

    serve = lib.mkEnableOption "accepting builds submitted by the other NixOS machines" // {
      default = self ? builder;
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
        hostNames = [ name ] ++ (host.aliases or [ ]) ++ host.addresses;
        publicKey = host.hostKey;
      }) peers;

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

          # Pinned here as well as in known_hosts, because nix hands ssh its
          # own throwaway known_hosts file when this is set -- so a build
          # never depends on the ambient one being right.
          publicHostKey = lib.elemAt (lib.splitString " " host.hostKey) 1;

          inherit (host.builder) system maxJobs speedFactor;

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

    (lib.mkIf (cfg.enable && cfg.serve) {
      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.user;
        shell = pkgs.bashInteractive;
        description = "Remote builds submitted by the other machines";

        # Every peer except this one -- a host has no reason to log into itself.
        openssh.authorizedKeys.keys = lib.mapAttrsToList (_: host: host.hostKey) (
          lib.filterAttrs (name: _: name != selfName) peers
        );
      };

      users.groups.${cfg.user} = { };

      nix.settings.trusted-users = [ cfg.user ];
    })
  ];
}
