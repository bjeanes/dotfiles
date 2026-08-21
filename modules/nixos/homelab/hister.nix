{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  svc = "hister";
  tsnet = "griffin-climb.ts.net";
in
{
  options.homelab.services.${svc} = {
    enable = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable ${svc}";
    };

    image = lib.mkOption {
      default = "ghcr.io/asciimoo/${svc}:latest";
      type = lib.types.str;
      description = "OCI image for ${svc}";
    };

    userHandling = lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = ''
        Run ${svc} in multi-user mode: every request is authenticated and each
        account gets its own document set. Accounts only exist once
        `create-user` has been run, so the instance is unusable until then.
      '';
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

    backupToNAS = lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = "Back up configDir to legacy location on NAS";
    };
  };

  config =
    let
      myLib = lib.${namespace};
      cfg = config.homelab.services.${svc};
      buildBackupScriptForDir = myLib.buildBackupScriptForDir pkgs svc;
      mkTailscaleQuadletContainer = myLib.mkTailscaleQuadletContainer pkgs config;

      inherit (config.virtualisation.quadlet) pods;

      podName = "${svc}-pod";
      fqdn = "${cfg.hostName}.${tsnet}";
      port = 4433;
    in
    lib.mkIf cfg.enable (
      lib.mkMerge [
        {
          # Ownership is deliberately left to podman (see the `:U` mount
          # below), so `-` rather than a user: `d` would otherwise reassert
          # root on every activation and undo it. Not group-readable: this
          # holds the full text of every page browsed, and nothing outside the
          # container reads it.
          systemd.tmpfiles.rules = [
            "d ${cfg.configDir} 0700 - - - -"
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

                  HISTER__SERVER__ADDRESS = "127.0.0.1:${toString port}";
                  HISTER__SERVER__BASE_URL = "https://${fqdn}";
                }
                // lib.optionalAttrs cfg.userHandling {
                  HISTER__APP__USER_HANDLING = "true";
                };
                volumes = [
                  # `:U` has podman chown the source to whatever uid the image
                  # runs as, so neither a host user nor that uid has to be
                  # named here. hister has no PUID/PGID indirection to point at
                  # a host-allocated id, and pinning one to match the image
                  # coincidentally reserves an id other containers commonly
                  # want. The chown is recursive and repeats on every start.
                  "${cfg.configDir}:/hister/data:U"
                ];
              };
              unitConfig = {
                AssertPathIsDirectory = [
                  cfg.configDir
                ];
              };
            };
          };
        }

        (mkTailscaleQuadletContainer "${svc}-tailscale" {
          inherit podName;
          hostname = cfg.hostName;
          https = port;
        })

        (lib.mkIf cfg.backupToNAS (buildBackupScriptForDir cfg.configDir { inherit (cfg) timeZone; }))
      ]
    );
}
