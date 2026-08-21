{ lib
, config
, pkgs
, namespace
, ...
}:
let
  tsnet = "griffin-climb.ts.net";
  myLib = lib.${namespace};

  setEnvFromFilesForContainer = myLib.setEnvFromFilesForContainer pkgs config;

  # Instance name mapped to the Unpackerr service it belongs to. Unpackerr
  # addresses instances as `UN_<SERVICE>_<N>_*` where N counts from zero
  # *within a service*, so a second Radarr is `UN_RADARR_1_*` -- the instance
  # name alone cannot derive the variable name.
  arrs = {
    sonarr = "sonarr";
    radarr = "radarr";
    radarr4k = "radarr";
    lidarr = "lidarr";
    # readarr = "readarr";
  };

  instances = lib.attrNames arrs;
  cfg = config.homelab.services.unpackerr;

  # Indexes are assigned across the *enabled* instances of each service so that
  # Unpackerr sees a contiguous run from zero. Deriving them from the instance
  # list instead would leave a disabled radarr stranding radarr4k at index 1
  # with nothing at index 0. Ordering is alphabetical and renumbering is
  # harmless -- Unpackerr keeps no state against the index, it just polls what
  # each one points at.
  indexOf = lib.listToAttrs (
    lib.concatMap
      (
        service:
        lib.imap0 (i: name: lib.nameValuePair name i) (
          lib.filter (name: arrs.${name} == service && cfg.${name}.enable) instances
        )
      )
      (lib.unique (lib.attrValues arrs))
  );

  # e.g. "UN_RADARR_1_" for radarr4k
  envPrefix = name: "UN_${lib.toUpper arrs.${name}}_${toString indexOf.${name}}_";
in
{
  options.homelab.services.unpackerr = lib.mergeAttrsList (
    lib.map
      (arr: {
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
      })
      instances
  );

  config = lib.mkIf cfg.enable (
    lib.mkMerge (
      lib.map
        (
          arr:

          let
            instance = config.homelab.services.unpackerr.${arr};
            prefix = envPrefix arr;
          in
          lib.mkIf instance.enable (
            lib.mkMerge [
              {
                virtualisation.oci-containers.containers.unpackerr.environment = {
                  "${prefix}URL" = instance.url;
                  "${prefix}PROTOCOLS " = " torrent,usenet";
                };
              }
              (setEnvFromFilesForContainer "unpackerr" {
                "${prefix}API_KEY" = instance.apiKeyFile;
              })
            ]
          )
        )
        instances
    )
  );
}
