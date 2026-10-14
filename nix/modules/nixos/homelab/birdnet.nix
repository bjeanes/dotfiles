{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  svc = "birdnet";
in
{
  options.homelab.services.${svc} = flake.lib.mkHomelabServiceOptions config svc {
    # image = "ghcr.io/tphakala/birdnet-go:latest";
    image = "ghcr.io/tphakala/birdnet-go:nightly";
    hostName = svc;
    withUser = true;
  };

  config =
    let
      myLib = flake.lib;
      cfg = config.homelab.services.${svc};
      buildBackupScriptForDir = myLib.buildBackupScriptForDir pkgs svc;
      mkTailscaleQuadletContainer = myLib.mkTailscaleQuadletContainer pkgs config;
      mkQuadletDynamicEnvironment = myLib.mkQuadletDynamicEnvironment pkgs config;

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

          systemd.tmpfiles.rules = [
            # Ensure config directory exists, owned by user
            "d ${cfg.configDir}        0775 ${cfg.user} ${cfg.group} - -"
            "d ${cfg.configDir}/config 0775 ${cfg.user} ${cfg.group} - -"
            "d ${cfg.configDir}/data   0775 ${cfg.user} ${cfg.group} - -"

            # Ensure directory and contents belong to specified owner and group
            "Z ${cfg.configDir} - ${cfg.user} ${cfg.group} - -"
          ];

          virtualisation.quadlet = {
            pods.${podName} = { };
            containers = {
              ${svc} = {
                autoStart = true;
                containerConfig = {
                  pod = pods.${podName}.ref;
                  autoUpdate = "registry";
                  image = cfg.image;
                  environments = {
                    TZ = cfg.timeZone;
                  };
                  volumes = [
                    "${cfg.configDir}/config:/config"
                    "${cfg.configDir}/data:/data"
                  ];
                };
                unitConfig = {
                  AssertPathIsDirectory = [
                    "${cfg.configDir}/config"
                    "${cfg.configDir}/data"
                  ];
                };
              };
            };
          };
        }

        (mkTailscaleQuadletContainer "${svc}-tailscale" {
          inherit podName;
          hostname = cfg.hostName;
          https = 8080;
        })

        (mkQuadletDynamicEnvironment {
          containerName = svc;
          variables = {
            BIRDNET_UID = "${pkgs.coreutils}/bin/id -u ${cfg.user}";
            BIRDNET_GID = "${pkgs.getent}/bin/getent group ${cfg.group} | cut -d: -f3";
          };
        })

        (lib.mkIf cfg.backupToNAS (buildBackupScriptForDir cfg.configDir { inherit (cfg) timeZone; }))
      ]
    );

}
