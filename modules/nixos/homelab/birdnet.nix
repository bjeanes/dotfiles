{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  svc = "birdnet";
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
      # default = "ghcr.io/tphakala/birdnet-go:latest";
      default = "ghcr.io/tphakala/birdnet-go:nightly";
      type = lib.types.str;
      description = "OCI image for ${svc}";
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
      description = "Back up configDir to legacy location on NAS";
    };
  };

  config =
    let
      myLib = lib.${namespace};
      cfg = config.homelab.services.${svc};
      secrets = config.age.secrets;
      buildBackupScriptForDir = myLib.buildBackupScriptForDir pkgs svc;
      mkTailscaleQuadletContainer = myLib.mkTailscaleQuadletContainer pkgs config;
      mkQuadletDynamicEnvironment = myLib.mkQuadletDynamicEnvironment pkgs config;

      inherit (config.virtualisation.quadlet) containers pods;

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
          hostname = svc;
          https = 8080;
        })

        (mkQuadletDynamicEnvironment {
          containerName = svc;
          variables = {
            BIRDNET_UID = "${pkgs.coreutils}/bin/id -u ${svc}";
            BIRDNET_GID = "${pkgs.getent}/bin/getent group homelab | cut -d: -f3";
          };
        })
      ]
    );

}
