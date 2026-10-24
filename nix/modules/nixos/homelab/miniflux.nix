{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  svc = "miniflux";
in
{
  options.homelab.services.${svc} =
    flake.lib.mkHomelabServiceOptions config svc {
      description = ''
        Enable ${svc}, fronted by Nextflux.

        No account is created automatically. Until one is, the instance is
        unusable: `podman exec -it ${svc} /usr/bin/miniflux -create-admin`.
      '';
      image = "docker.io/miniflux/miniflux:latest";
      hostName = svc;
      dashboard.description = "News feeds (settings and admin)";
      # The tailnet root is nextflux, which has its own entry
      dashboard.path = "/miniflux/";
      # Services here have no per-path handlers yet
      exposeAs = "sidecar";
      backupDescription = "Back up ${svc}'s database dumps to legacy location on NAS";
    }
    // {
      nextfluxImage = lib.mkOption {
        default = "docker.io/electh/nextflux:latest";
        type = lib.types.str;
        description = "OCI image for the Nextflux frontend";
      };

      feedTheCommentsImage = lib.mkOption {
        default = "ghcr.io/bjeanes/feed-the-comments:latest";
        type = lib.types.str;
        description = "OCI image for the feed-the-comments feed rewriter";
      };

      dbImage = lib.mkOption {
        # Pinned to a major version and opted out of auto-update
        default = "docker.io/library/postgres:18-alpine";
        type = lib.types.str;
        description = "OCI image for the PostgreSQL backing ${svc}";
      };
    };

  config =
    let
      myLib = flake.lib;
      cfg = config.homelab.services.${svc};
      buildBackupScriptForDir = myLib.buildBackupScriptForDir pkgs svc;
      mkTailscaleQuadletExposure = myLib.mkTailscaleQuadletExposure pkgs config;

      inherit (config.virtualisation.quadlet) pods;

      podName = "${svc}-pod";
      fqdn = "${cfg.hostName}.${config.homelab.tailscale.tailnet}";

      pg = myLib.postgresFor svc;
      nextfluxName = "nextflux";
      ftcName = "feed-the-comments";

      port = 8080;
      nextfluxPort = 3000;
      ftcPort = 3001;

      # Nextflux is a static SPA built for `/`, so it gets the root and
      # Miniflux moves under a prefix. Same origin also means the API is
      # just `https://${fqdn}/miniflux` when logging in to Nextflux.
      basePath = "/miniflux";

      backupDir = "${cfg.configDir}/backups";

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
                  DATABASE_URL = "${pg.url}?sslmode=disable";
                  RUN_MIGRATIONS = "1";

                  # tailscaled terminates TLS. Miniflux would otherwise only
                  # learn it is behind HTTPS from the first trusted
                  # `X-Forwarded-Proto`, and issue non-`Secure` cookies until then.
                  HTTPS = "1";
                  TRUSTED_REVERSE_PROXY_NETWORKS = "127.0.0.1/32";

                  # So feeds can be subscribed through feed-the-comments at
                  # `http://localhost:${toString ftcPort}`. The tailnet URL
                  # isn't an option: it's private too, and tailscaled runs in
                  # userspace so nothing else in the pod can route to it.
                  FETCHER_ALLOW_PRIVATE_NETWORKS = "1";
                };
                notify = "healthy";
                healthCmd = "/usr/bin/miniflux -healthcheck auto";
                healthInterval = "10s";
                healthTimeout = "5s";
                healthRetries = 5;
              };
              unitConfig = {
                After = [ pg.unit ];
                Requires = [ pg.unit ];
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

            containers.${ftcName} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                autoUpdate = "registry";
                image = cfg.feedTheCommentsImage;
                environments = {
                  TZ = cfg.timeZone;
                  PORT = toString ftcPort;
                  HTTP_HOST = "127.0.0.1";
                  # For links only; tailscaled strips the path before proxying
                  PUBLIC_URL = "https://${fqdn}/${ftcName}";
                };
              };
            };
          };
        }

        (myLib.mkQuadletPostgres config pg {
          inherit podName;
          inherit (cfg) timeZone;
          image = cfg.dbImage;
        })

        {
          homelab.dashboard.entries.nextflux = {
            href = "https://${fqdn}/";
            icon = "mdi-rss-box";
            description = "Read news feeds";
          };
        }

        (mkTailscaleQuadletExposure svc {
          https = {
            "/" = nextfluxPort;
            # tailscaled strips the mount point before proxying, so the
            # upstream has to put it back for Miniflux's router.
            "${basePath}/" = "http://localhost:${toString port}${basePath}/";
            "/${ftcName}/" = ftcPort;
          };
        })

        (lib.mkIf cfg.backupToNAS (
          lib.mkMerge [
            (myLib.mkPostgresDump pkgs config svc pg backupDir)
            (buildBackupScriptForDir backupDir { inherit (cfg) timeZone; })
          ]
        ))
      ]
    );
}
