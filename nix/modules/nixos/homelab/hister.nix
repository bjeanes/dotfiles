{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  svc = "hister";
in
{
  options.homelab.services.${svc} =
    flake.lib.mkHomelabServiceOptions config svc {
      image = "ghcr.io/asciimoo/${svc}:latest";
      hostName = svc;
      exposeAs = "service";
    }
    // {
      userHandling = lib.mkOption {
        default = true;
        type = lib.types.bool;
        description = ''
          Run ${svc} in multi-user mode: every request is authenticated and each
          account gets its own document set. Accounts only exist once
          `create-user` has been run, so the instance is unusable until then.
        '';
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

                  HISTER__SERVER__ADDRESS = "${myLib.listenAddressFor cfg}:${toString port}";
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

        (mkTailscaleQuadletExposure svc { https = port; })

        (lib.mkIf cfg.backupToNAS (buildBackupScriptForDir cfg.configDir { inherit (cfg) timeZone; }))
      ]
    );
}
