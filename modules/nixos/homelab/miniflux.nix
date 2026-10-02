{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  svc = "miniflux";
  tsnet = "griffin-climb.ts.net";
in
{
  options.homelab.services.${svc} = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = ''
        Enable ${svc}, fronted by Nextflux.

        No account is created automatically. Until one is, the instance is
        unusable: `podman exec -it ${svc} /usr/bin/miniflux -create-admin`.
      '';
    };

    image = lib.mkOption {
      default = "docker.io/miniflux/miniflux:latest";
      type = lib.types.str;
      description = "OCI image for ${svc}";
    };

    nextfluxImage = lib.mkOption {
      default = "docker.io/electh/nextflux:latest";
      type = lib.types.str;
      description = "OCI image for the Nextflux frontend";
    };

    dbImage = lib.mkOption {
      # Pinned to a major version and opted out of auto-update
      default = "docker.io/library/postgres:18-alpine";
      type = lib.types.str;
      description = "OCI image for the PostgreSQL backing ${svc}";
    };

    hostName = lib.mkOption {
      default = svc;
      type = lib.types.str;
      description = "Tailnet hostname to expose Nextflux and ${svc} as";
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
      description = "Back up ${svc}'s database dumps to legacy location on NAS";
    };
  };

  config =
    let
      myLib = lib.${namespace};
      cfg = config.homelab.services.${svc};
      buildBackupScriptForDir = myLib.buildBackupScriptForDir pkgs svc;
      mkTailscaleQuadletContainer = myLib.mkTailscaleQuadletContainer pkgs config;

      inherit (config.virtualisation.quadlet) pods volumes;

      podName = "${svc}-pod";
      fqdn = "${cfg.hostName}.${tsnet}";

      dbName = "${svc}-db";
      nextfluxName = "nextflux";

      port = 8080;
      nextfluxPort = 3000;
      dbPort = 5432;

      # Nextflux is a static SPA built for `/`, so it gets the root and
      # Miniflux moves under a prefix. Same origin also means the API is
      # just `https://${fqdn}/miniflux` when logging in to Nextflux.
      basePath = "/miniflux";

      dbUser = svc;
      dbDatabase = svc;
      dbPassword = svc;

      backupDir = "${cfg.configDir}/backups";
      podman = "${config.virtualisation.podman.package}/bin/podman";

      # Upstream's Caddyfile, bound to loopback like the rest of the pod, plus
      # prefilling the login form's server URL via the `?serverUrl=` it reads.
      caddyfile = pkgs.writeText "nextflux-Caddyfile" ''
        :${toString nextfluxPort}

        bind 127.0.0.1
        root * /srv

        @login {
          path /login
          not query serverUrl=*
        }
        redir @login /login?serverUrl=https://${fqdn}${basePath} 302

        try_files {path} {path}/ /index.html
        file_server
      '';
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          systemd.tmpfiles.rules = [
            "d ${cfg.configDir} 0700 - - - -"
            "d ${backupDir} 0700 - - - -"
          ];

          virtualisation.quadlet = {
            pods.${podName} = { };

            volumes."${svc}-pgdata" = { };

            containers.${dbName} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                image = cfg.dbImage;
                exec = [
                  "postgres"
                  "-c"
                  "listen_addresses=127.0.0.1"
                ];
                environments = {
                  TZ = cfg.timeZone;
                  POSTGRES_USER = dbUser;
                  POSTGRES_DB = dbDatabase;
                  POSTGRES_PASSWORD = dbPassword;
                };
                volumes = [
                  "${volumes."${svc}-pgdata".ref}:/var/lib/postgresql"
                ];
                notify = "healthy";
                healthCmd = "pg_isready -U ${dbUser}";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 5;
              };
              # First boot runs initdb before the healthcheck can pass.
              serviceConfig.TimeoutStartSec = "300";
            };

            containers.${svc} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                autoUpdate = "registry";
                image = cfg.image;
                environments = {
                  TZ = cfg.timeZone;

                  LISTEN_ADDR = "127.0.0.1:${toString port}";
                  BASE_URL = "https://${fqdn}${basePath}/";
                  DATABASE_URL = "postgres://${dbUser}:${dbPassword}@localhost:${toString dbPort}/${dbDatabase}?sslmode=disable";
                  RUN_MIGRATIONS = "1";

                  # tailscaled terminates TLS. Miniflux would otherwise only
                  # learn it is behind HTTPS from the first trusted
                  # `X-Forwarded-Proto`, and issue non-`Secure` cookies until then.
                  HTTPS = "1";
                  TRUSTED_REVERSE_PROXY_NETWORKS = "127.0.0.1/32";
                };
                notify = "healthy";
                healthCmd = "/usr/bin/miniflux -healthcheck auto";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 5;
              };
              unitConfig = {
                After = [ "${dbName}.service" ];
                Requires = [ "${dbName}.service" ];
              };
            };

            containers.${nextfluxName} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                autoUpdate = "registry";
                image = cfg.nextfluxImage;
                environments = {
                  TZ = cfg.timeZone;
                };
                volumes = [
                  "${caddyfile}:/etc/caddy/Caddyfile:ro"
                ];
              };
            };
          };
        }

        (mkTailscaleQuadletContainer "${svc}-tailscale" {
          inherit podName;
          hostname = cfg.hostName;
          https = {
            "/" = nextfluxPort;
            # tailscaled strips the mount point before proxying, so the
            # upstream has to put it back for Miniflux's router.
            "${basePath}/" = "http://localhost:${toString port}${basePath}/";
          };
        })

        (lib.mkIf cfg.backupToNAS (
          lib.mkMerge [
            {
              systemd.services."${svc}-db-dump" = {
                requiredBy = [ "backup-${svc}-to-NAS.service" ];
                before = [ "backup-${svc}-to-NAS.service" ];
                requires = [ "${dbName}.service" ];
                after = [ "${dbName}.service" ];
                serviceConfig.Type = "oneshot";
                script = ''
                  set -euo pipefail
                  tmp="$(${pkgs.coreutils}/bin/mktemp ${backupDir}/.${svc}.dump.XXXXX)"
                  trap 'rm -f "$tmp"' EXIT
                  ${podman} exec ${dbName} \
                    pg_dump -U ${dbUser} -d ${dbDatabase} --format=custom > "$tmp"
                  mv -f "$tmp" ${backupDir}/${svc}.dump
                  trap - EXIT
                '';
              };
            }

            (buildBackupScriptForDir backupDir { inherit (cfg) timeZone; })
          ]
        ))
      ]
    );
}
