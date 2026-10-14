{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  svc = "readeck";
  tsnet = "griffin-climb.ts.net";
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
      default = "codeberg.org/${svc}/${svc}:latest";
      type = lib.types.str;
      description = "OCI image for ${svc}";
    };

    hostName = lib.mkOption {
      default = svc;
      type = lib.types.str;
      description = "Tailnet hostname to expose ${svc} as";
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
      description = "Back up ${svc}'s exports to legacy location on NAS";
    };
  };

  config =
    let
      myLib = flake.lib;
      cfg = config.homelab.services.${svc};
      buildBackupScriptForDir = myLib.buildBackupScriptForDir pkgs svc;
      mkTailscaleQuadletContainer = myLib.mkTailscaleQuadletContainer pkgs config;

      inherit (config.virtualisation.quadlet) pods;

      podName = "${svc}-pod";
      fqdn = "${cfg.hostName}.${tsnet}";
      port = 8000;

      # The image's working directory. Readeck writes `config.toml` (holding
      # its generated secret key) here on first start, and keeps the SQLite
      # database and archived articles under `data/`.
      dataDir = "${cfg.configDir}/data";

      # Nightly `readeck export`s land here. The export runs an hour before
      # `buildBackupScriptForDir`'s 02:00 rsync.
      backupDir = "${cfg.configDir}/backups";
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
              "d ${cfg.configDir} 0700 ${user} ${group} - -"
              "d ${dataDir}       0700 ${user} ${group} - -"
              "d ${backupDir}     0700 ${user} ${group} - -"

              "Z ${cfg.configDir} - ${user} ${group} - -"
            ];

          virtualisation.quadlet = {
            pods.${podName} = { };

            containers.${svc} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                autoUpdate = "registry";
                image = cfg.image;

                # The image would otherwise run as root. It's a static binary
                # on busybox, so any uid works as long as it owns the volumes.
                user = cfg.user;
                podmanArgs = [ "--hostuser=${cfg.user}" ];

                environments = {
                  TZ = cfg.timeZone;

                  # Only the Tailscale sidecar in the pod needs to reach this,
                  # and it's within the default trusted proxies.
                  READECK_SERVER_HOST = "127.0.0.1";
                  READECK_SERVER_PORT = toString port;
                  READECK_SERVER_BASE_URL = "https://${fqdn}";
                };
                volumes = [
                  "${dataDir}:/readeck"
                  "${backupDir}:/backups"
                ];

                # Gives `podman auto-update` something to roll back on.
                healthCmd = "/bin/readeck healthcheck -config config.toml";
                healthInterval = "30s";
                healthTimeout = "5s";
                healthRetries = 3;
                healthStartPeriod = "20s";
              };
              unitConfig = {
                AssertPathIsDirectory = [
                  dataDir
                  backupDir
                ];
              };
            };
          };

          systemd.services."${svc}-export" = {
            description = "Export ${svc}'s data";
            startAt = "*-*-* 01:00:00 ${cfg.timeZone}";
            requires = [ "${svc}.service" ];
            after = [ "${svc}.service" ];
            serviceConfig.Type = "oneshot";
            script = ''
              set -eu
              ${pkgs.podman}/bin/podman exec ${svc} \
                /bin/readeck export -config config.toml /backups/${svc}.zip.tmp
              mv ${backupDir}/${svc}.zip.tmp ${backupDir}/${svc}.zip
            '';
          };
        }

        (mkTailscaleQuadletContainer "${svc}-tailscale" {
          inherit podName;
          hostname = cfg.hostName;
          https = port;
        })

        (lib.mkIf cfg.backupToNAS (buildBackupScriptForDir backupDir { inherit (cfg) timeZone; }))
      ]
    );
}
