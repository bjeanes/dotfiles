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

  setEnvFromFilesForContainer = myLib.setEnvFromFilesForContainer pkgs config;

  arrs = [
    "sonarr"
    "radarr"
    "radarr4k"
  ];
  cfg = config.homelab.services.recyclarr;

  yamlFormat = pkgs.formats.yaml { };

  # Recyclarr resolves `!env_var` when it loads the config, but a YAML tag
  # cannot survive the JSON round-trip `pkgs.formats.yaml` performs. Tagged
  # values are emitted as sentinel scalars and turned back into tags below, so
  # the document itself stays ordinary Nix data rather than hand-indented text.
  envVar = name: "@env_var:${name}@";

  mkInstance =
    arr: attrs:
    {
      base_url = cfg.${arr}.url;
      api_key = envVar "${lib.toUpper arr}_API_KEY";

      # Drop custom formats no longer named here rather than leaving them
      # behind in the instance, still scoring releases.
      delete_old_custom_formats = true;
    }
    // attrs;

  templates = map (template: {
    inherit template;
  });

  # A `quality_definition` applies per *instance*, not per profile, and merges
  # by replacement -- include two definition templates in one instance and
  # whichever comes last silently wins. That is why 1080p and 2160p movies are
  # two Radarr instances here rather than two profiles on one.
  sonarrSeries = mkInstance "sonarr" {
    include = templates [
      "sonarr-quality-definition-series"
      "sonarr-v4-quality-profile-web-1080p-alternative"
      "sonarr-v4-custom-formats-web-1080p"
    ];

    custom_formats = [
      {
        trash_ids = [
          "32b367365729d530ca1c124a0b180c64" # Bad Dual Groups
          "82d40da2bc6923f41e14394075dd4b03" # No-RlsGroup
          "e1a997ddb54e3ecbfe06341ad323c458" # Obfuscated
          "06d66ab109d4d2eddb2794d21526d140" # Retags
          "1b3994c551cbb92a2c781af061f4ab44" # Scene
        ];
        assign_scores_to = [ { name = "WEB-1080p"; } ];
      }
    ];
  };

  radarrMovies = mkInstance "radarr" {
    include = templates [
      "radarr-quality-definition-movie"
      "radarr-quality-profile-hd-bluray-web"
      "radarr-custom-formats-hd-bluray-web"
    ];
  };

  radarrMovies4k = mkInstance "radarr4k" {
    include = templates [
      "radarr-quality-definition-movie"
      "radarr-quality-profile-uhd-bluray-web"
      "radarr-custom-formats-uhd-bluray-web"
    ];
  };

  radarrInstances =
    lib.optionalAttrs cfg.radarr.enable { movies = radarrMovies; }
    // lib.optionalAttrs cfg.radarr4k.enable { movies-4k = radarrMovies4k; };

  configData =
    lib.optionalAttrs cfg.sonarr.enable { sonarr.series = sonarrSeries; }
    // lib.optionalAttrs (radarrInstances != { }) { radarr = radarrInstances; };

  recyclarrConfig =
    pkgs.runCommand "recyclarr.yml"
      {
        generated = yamlFormat.generate "recyclarr.generated.yml" configData;
      }
      ''
        sed -E "s|['\"]@env_var:([^@'\"]+)@['\"]|!env_var \1|g" "$generated" > $out

        if grep -q '@env_var:' $out; then
          echo "recyclarr.yml: sentinel survived tag substitution" >&2
          exit 1
        fi
      '';
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
      [
        {
          virtualisation.oci-containers.containers.recyclarr.volumes = [
            "${recyclarrConfig}:/config/recyclarr.yml:ro"
          ];
        }
      ]
      ++ lib.map (
        arr:

        let
          cfg = config.homelab.services.recyclarr.${arr};
        in
        lib.mkIf cfg.enable (
          setEnvFromFilesForContainer "recyclarr" {
            "${lib.toUpper arr}_API_KEY" = cfg.apiKeyFile;
          }
        )
      ) arrs
    )
  );
}
