{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
let
  tsnet = "griffin-climb.ts.net";
  myLib = lib.${namespace};

  setEnvFromFilesForContainer = myLib.setEnvFromFilesForContainer config;
  setEnvFromCommandsForContainer = myLib.setEnvFromCommandsForContainer config;

  arrs = [
    "sonarr"
    "radarr"
  ];
  cfg = config.homelab.services.recyclarr;
in
{
  options.homelab.services.recyclarr = lib.mergeAttrsList (
    lib.map (arr: {
      ${arr} = {
        enable = lib.mkOption {
          default = config.homelab.services.${arr}.enable;
          type = lib.types.bool;
          description = "Enable Recyclarr on ${arr}";
        };

        url = lib.mkOption {
          # TODO: make this not coupled to Tailscale
          default =
            if config.homelab.services.${arr}.tailscale.enable then "https://${arr}.${tsnet}" else null;
          type = lib.types.str;
          description = "URL for Recyclarr to use for ${arr}";
        };

        apiKeyFile = lib.mkOption {
          default = config.age.secrets."${arr}-api-key".path;
          type = lib.types.str;
          description = "File with contents for Recyclarr to use as API key for ${arr}";
        };
      };
    }) arrs
  );

  config = lib.mkIf cfg.enable (
    lib.mkMerge (
      lib.map (
        arr:

        let
          cfg = config.homelab.services.recyclarr.${arr};
        in
        lib.mkIf cfg.enable (
          lib.mkMerge [
            {
              virtualisation.oci-containers.containers.recyclarr.environment = {
                "${lib.toUpper arr}_URL" = cfg.url;
              };
            }
            (setEnvFromFilesForContainer "recyclarr" {
              "${lib.toUpper arr}_API_KEY" = cfg.apiKeyFile;
            })
          ]
        )
      ) arrs
    )
  );
}
