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
    "lidarr"
    # "readarr"
  ];
  cfg = config.homelab.services.unpackerr;
in
{
  options.homelab.services.unpackerr = lib.mergeAttrsList (
    lib.map (arr: {
      ${arr} = {
        enable = lib.mkOption {
          default = config.homelab.services.${arr}.enable;
          type = lib.types.bool;
          description = "Enable unpackerr on ${arr}";
        };

        url = lib.mkOption {
          # TODO: make this not coupled to Tailscale
          default =
            if config.homelab.services.${arr}.tailscale.enable then "https://${arr}.${tsnet}" else null;
          type = lib.types.str;
          description = "URL for Unpacker to use for ${arr}";
        };

        apiKeyFile = lib.mkOption {
          default = config.age.secrets."${arr}-api-key".path;
          type = lib.types.str;
          description = "File with contents for Unpacker to use as API key for ${arr}";
        };
      };
    }) arrs
  );

  config = lib.mkIf cfg.enable (
    lib.mkMerge (
      lib.map (
        arr:

        let
          cfg = config.homelab.services.unpackerr.${arr};
        in
        lib.mkIf cfg.enable (
          lib.mkMerge [
            {
              virtualisation.oci-containers.containers.unpackerr.environment = {
                "UN_${lib.toUpper arr}_0_URL" = cfg.url;
              };
            }
            (setEnvFromFilesForContainer "unpackerr" {
              "UN_${lib.toUpper arr}_0_API_KEY" = cfg.apiKeyFile;
            })
          ]
        )
      ) arrs
    )
  );
}
