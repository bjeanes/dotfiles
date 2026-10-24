{
  config,
  lib,
  flake,
  pkgs,
  ...
}:
let
  svc = "silverbullet";
in
{
  options.homelab.services.${svc} = flake.lib.mkHomelabServiceOptions config svc {
    image = "ghcr.io/silverbulletmd/silverbullet:latest";
    hostName = svc;
    dashboard.description = "Personal notes";
    dashboard.group = "Notes";
    # Its space is shared over Taildrive, which belongs to a machine
    exposeAs = "sidecar";
    withUser = true;
  };

  config =
    let
      myLib = flake.lib;
      cfg = config.homelab.services.${svc};
      secrets = config.age.secrets;

      inherit (config.virtualisation.quadlet) pods;
      podName = "${svc}-pod";
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
              # Ensure config directory exists, owned by user
              "d ${cfg.configDir}    0775 ${user} ${group} - -"

              # Ensure directory and contents belong to specified owner and group
              "Z ${cfg.configDir} - ${user} ${group} - -"
            ];

          virtualisation.quadlet = {
            pods.${podName} = { };

            containers.${svc} = {
              autoStart = true;
              containerConfig = {
                pod = pods.${podName}.ref;
                image = cfg.image;
                autoUpdate = "registry";
                podmanArgs = [ "--hostuser=${cfg.user}" ];
                volumes = [
                  "${cfg.configDir}:/space"
                ];
                environments = {
                  TZ = cfg.timeZone;
                  SB_PORT = "3000";
                };
              };
            };
          };
        }

        # {
        #   systemd.tmpfiles.rules = [
        #     # Add ACLs to Silverbullet config directory for Resilio
        #     "A+ ${cfg.configDir} - - - - group:rslsync:rwx,default:group:rslsync:rwx"
        #   ];
        #
        #   services.resilio = {
        #     enable = true;
        #     sharedFolders = [
        #       {
        #         directory = cfg.configDir;
        #         secretFile = secrets.silverbullet-resilio-sync-key.path;
        #         knownHosts = [ ];
        #         searchLAN = true;
        #         useDHT = false;
        #         useRelayServer = true;
        #         useSyncTrash = true;
        #         useTracker = true;
        #       }
        #     ];
        #   };
        # }

        (lib.mkIf cfg.backupToNAS (
          myLib.buildBackupScriptForDir pkgs svc cfg.configDir { inherit (cfg) timeZone; }
        ))

        (myLib.mkTailscaleQuadletExposure pkgs config svc {
          inherit podName;
          https = 3000;

          # Runs tailscaled as the same user Silverbullet drops to, so pages
          # written over Taildrive are owned by it and remain editable in the
          # app. Needs `drive:share` on this node in the tailnet policy file,
          # plus a `tailscale.com/cap/drive` grant for whoever mounts it.
          inherit (cfg) user group;
          drive.space = cfg.configDir;
        })

      ]
    );
}
