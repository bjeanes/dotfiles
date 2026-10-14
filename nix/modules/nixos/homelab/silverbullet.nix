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
    withUser = true;
  };

  config =
    let
      myLib = flake.lib;
      cfg = config.homelab.services.${svc};
      svcName = myLib.containerSvcName config svc;
      secrets = config.age.secrets;
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

          systemd.services.${myLib.containerSvcName config "${svc}-tailscale"} = {
            partOf = [ "${svc}.service" ];
          };

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

          virtualisation.oci-containers = {
            containers = {
              ${svc} = {
                image = cfg.image;
                autoStart = true;
                dependsOn = [ "${svc}-tailscale" ];
                volumes = [
                  "${cfg.configDir}:/space"
                ];
                extraOptions = [
                  "--network=container:${svc}-tailscale"
                  "--hostuser=${cfg.user}"
                ];
                labels = {
                  "io.containers.autoupdate" = "registry";
                };
                environment = {
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

        (myLib.mkTailscaleContainer pkgs config "${svc}-tailscale" {
          hostname = svc;
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
