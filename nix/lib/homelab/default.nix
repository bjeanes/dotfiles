{ flake, lib, ... }:
{
  # Options every `homelab.services.<svc>` shares. Anything service-specific,
  # including overriding one of these, goes on with `//`.
  mkHomelabServiceOptions =
    config: svc:
    {
      description ? "Enable ${svc}",
      # `null` omits the option
      image ? null,
      # `null` omits the option; otherwise the default tailnet hostname
      hostName ? null,
      # How the service is put on the tailnet; see `tailscale.exposeAs`
      exposeAs ? "service",
      # Defaults for the `dashboard` options below
      dashboard ? { },
      withUser ? false,
      backupDescription ? "Back up configDir to legacy location on NAS",
    }:
    {
      enable = lib.mkOption {
        default = false;
        type = lib.types.bool;
        inherit description;
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

      backupToNAS = lib.mkOption {
        default = true;
        type = lib.types.bool;
        description = backupDescription;
      };
    }
    // lib.optionalAttrs (image != null) {
      image = lib.mkOption {
        default = image;
        type = lib.types.str;
        description = "OCI image for ${svc}";
      };
    }
    // lib.optionalAttrs (hostName != null) {
      hostName = lib.mkOption {
        default = hostName;
        type = lib.types.str;
        description = "Tailnet hostname to expose ${svc} as";
      };

      tailscale = {
        exposeAs = lib.mkOption {
          default = exposeAs;
          # It follows from how the service is used (e.g. shared into other
          # tailnets), not from which host runs it
          readOnly = true;
          type = lib.types.enum [
            "sidecar"
            "service"
          ];
          description = ''
            How ${svc} is put on the tailnet: as its own machine through a
            Tailscale sidecar in its pod, or as a Tailscale Service hosted by
            this machine's tailscaled. Set by ${svc}'s module.

            Switching to `service` frees the hostname only once the sidecar's
            machine is deleted from the tailnet, and the Service has to be
            defined there under the same name.
          '';
        };

        localPort = lib.mkOption {
          default = null;
          type = lib.types.nullOr lib.types.port;
          description = ''
            Port on the host's 127.0.0.1 that ${svc} is published on when
            exposed as a Tailscale Service. Defaults to the port it listens on
            in its pod.
          '';
        };
      };

      dashboard = {
        enable = lib.mkOption {
          default = dashboard.enable or true;
          type = lib.types.bool;
          description = "List ${svc} on the homelab dashboard";
        };

        group = lib.mkOption {
          default = dashboard.group or "Services";
          type = lib.types.str;
          description = "Dashboard group ${svc} is listed under";
        };

        icon = lib.mkOption {
          default = dashboard.icon or "${svc}.png";
          type = lib.types.nullOr lib.types.str;
          description = "Dashboard icon for ${svc}: a dashboard-icons name, `si-`/`mdi-` icon or URL";
        };

        description = lib.mkOption {
          default = dashboard.description or null;
          type = lib.types.nullOr lib.types.str;
          description = "Dashboard description for ${svc}";
        };

        path = lib.mkOption {
          default = dashboard.path or "/";
          type = lib.types.str;
          description = "Path under ${svc}'s tailnet hostname that the dashboard links to";
        };
      };
    }
    // lib.optionalAttrs withUser {
      user = lib.mkOption {
        default = flake.lib.coalesce config.homelab.user svc;
        type = lib.types.str;
        description = "User to run ${svc} service as";
      };

      group = lib.mkOption {
        default = config.homelab.group;
        type = lib.types.str;
        description = "Group to run the ${svc} service as";
      };
    };

  # A sidecar shares the pod's loopback, but a published port arrives on the
  # pod's network interface.
  listenAddressFor = cfg: if cfg.tailscale.exposeAs == "service" then "0.0.0.0" else "127.0.0.1";

  # Naming for a service's Postgres sidecar, shared between the container,
  # the app's connection settings and dumps. Only reachable within the pod,
  # hence the throwaway credentials.
  postgresFor = svc: rec {
    container = "${svc}-db";
    unit = "${container}.service";
    volume = "${svc}-pgdata";
    user = svc;
    database = svc;
    password = svc;
    port = 5432;
    url = "postgres://${user}:${password}@localhost:${toString port}/${database}";
  };

  mkQuadletPostgres =
    config: pg:
    {
      image,
      podName,
      timeZone,
      # pg18 images keep PGDATA in a major-versioned subdirectory, so the
      # volume goes one level up.
      dataPath ? "/var/lib/postgresql",
      # Each becomes a `-c` server setting
      settings ? [ ],
      # Merged over the defaults below
      containerConfig ? { },
    }:
    let
      inherit (config.virtualisation.quadlet) pods volumes;
    in
    {
      virtualisation.quadlet = {
        volumes.${pg.volume} = { };

        containers.${pg.container} = {
          autoStart = true;
          containerConfig = {
            pod = pods.${podName}.ref;
            inherit image;
            exec = [
              "postgres"
              "-c"
              "listen_addresses=127.0.0.1"
            ]
            ++ lib.concatMap (s: [
              "-c"
              s
            ]) settings;
            environments = {
              TZ = timeZone;
              POSTGRES_USER = pg.user;
              POSTGRES_DB = pg.database;
              POSTGRES_PASSWORD = pg.password;
            };
            volumes = [
              "${volumes.${pg.volume}.ref}:${dataPath}"
            ];
            # `Notify=healthy` makes the unit reach READY only once
            # `pg_isready` passes, so the app can order itself behind a
            # database that will actually accept a connection rather than one
            # whose process merely exists.
            notify = "healthy";
            healthCmd = "pg_isready -U ${pg.user}";
            healthInterval = "10s";
            healthTimeout = "5s";
            healthRetries = 5;
          }
          // containerConfig;
          # First boot runs initdb before the healthcheck can pass.
          serviceConfig.TimeoutStartSec = "300";
        };
      };
    };

  # A oneshot run immediately before `backup-<svc>-to-NAS`, to leave a
  # consistent snapshot of live state for the rsync to copy. If it fails, the
  # backup doesn't run.
  mkPreBackupJob =
    svc:
    {
      name,
      description,
      requires ? [ ],
      script,
    }:
    {
      systemd.services."${svc}-${name}" = {
        inherit description script requires;
        requiredBy = [ "backup-${svc}-to-NAS.service" ];
        before = [ "backup-${svc}-to-NAS.service" ];
        after = requires;
        serviceConfig.Type = "oneshot";
      };
    };

  # `pg_dump` the sidecar to `<backupDir>/<svc>.dump` ahead of the NAS backup
  mkPostgresDump =
    pkgs: config: svc: pg: backupDir:
    flake.lib.mkPreBackupJob svc {
      name = "db-dump";
      description = "Dump ${svc}'s database";
      requires = [ pg.unit ];
      script = ''
        set -euo pipefail
        tmp="$(${pkgs.coreutils}/bin/mktemp ${backupDir}/.${svc}.dump.XXXXX)"
        trap 'rm -f "$tmp"' EXIT
        ${config.virtualisation.podman.package}/bin/podman exec ${pg.container} \
          pg_dump -U ${pg.user} -d ${pg.database} --format=custom > "$tmp"
        mv -f "$tmp" ${backupDir}/${svc}.dump
        trap - EXIT
      '';
    };

  # A path option defaulting to the agenix secret `<svc>-<secret>`
  mkSecretFileOption =
    config: svc: secret: description:
    lib.mkOption {
      default = config.age.secrets."${svc}-${secret}".path;
      type = lib.types.str;
      inherit description;
    };
}
