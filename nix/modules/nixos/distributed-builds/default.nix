# Distributed builds across the NixOS machines in this flake. Tulgey, a fanless 2-core wall panel with kernel patches to
# compile, is the motivating case: it hands its builds to machines that can actually do them.
#
# The topology is deliberately one-directional -- builders build, clients delegate, and no host does both. It started as
# a symmetric mesh and that deadlocked the entire fleet: a host serving a remote build re-delegates it through its own
# /etc/nix/machines, so A hands a derivation to B, B hands it back to A, and both then block forever waiting for the
# output-path lock the other already holds. `waiting for lock on '...'`, indefinitely, on every machine at once. An
# assertion below enforces the invariant, because the failure is silent until everything is wedged.
#
# Authentication reuses each machine's SSH *host* key as its client identity.  Those public keys are already in the
# registry (agenix needs them anyway).
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
  self = peers.${selfName} or { };
in
{
  options.distributed-builds = {
    serve = lib.mkEnableOption "accepting builds submitted by the build cluster's clients" // {
      default = self ? builder;
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !(cfg.client && cfg.serve);
          message = ''
            distributed-builds: ${selfName} is set up as both a client and a
            builder. A host that delegates while also accepting delegated work
            can hand a derivation to a peer that hands it straight back, and
            both then wait forever on their own copy of that output path's
            lock -- with no error, just a build that never finishes.

            Give it `builder` in the host registry or `buildClient = true`,
            not both.
          '';
        }
      ];
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

      nix = {
        settings = {
          trusted-users = [ cfg.user ];

          # Bound with `maxJobs` in the registry so concurrent jobs cannot
          # oversubscribe the machine. Nix defaults this to 0, meaning every
          # job gets every core, which is how a builder ends up with several
          # times its core count in compilers and runs itself out of memory.
          cores = self.builder.cores;
        };

        # These boxes are servers first -- Plex, qbittorrent, postgres, the
        # *arrs -- and builders second, so builds yield to them. `batch` rather
        # than `idle` for the CPU: the option's own docs warn that `idle` can
        # starve work outright, and is meant for machines that are idle most of
        # the time. Disk is the one that actually hurts interactive use, so
        # that one does get `idle`.
        daemonCPUSchedPolicy = "batch";
        daemonIOSchedClass = "idle";
      };
    })
  ];
}
