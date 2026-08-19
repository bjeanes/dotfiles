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

  /*
    Anti-churn score knobs, applied on top of each guide profile.

    Every TRaSH profile ships `min_upgrade_format_score: 1` and
    `cutoff_format_score: 10000`, which together say "re-download whenever any
    release scores a single point higher, and never stop looking". That is the
    main reason several copies of one title end up in the download client at
    once: each marginally better release that appears qualifies as an upgrade
    and is grabbed while the previous one is still downloading.

    `min_format_score` stays at 0 deliberately -- a bad release beats no
    release. Quality is enforced on the way *up*, not at the door.

    CALIBRATING the two placeholders: run an interactive search in the instance
    on something you already have and read the per-release custom format score
    breakdown. Set `until_score` just above what a release you would be content
    with scores, and `min_upgrade_format_score` to a gap that represents a
    genuine improvement rather than a different release group. Both placeholders
    err toward *less* churn, so a wrong guess is not destructive: too high a
    `min_upgrade_format_score` or too low an `until_score` just means upgrading
    stops sooner than it could.

    PAIRS WITH these UI settings, which Recyclarr cannot manage:

      Settings -> Profiles -> Delay Profiles
        Set a torrent delay (30-60 min is a reasonable start). Without one the
        instance grabs the first acceptable release the moment it appears,
        rather than waiting to see the batch and taking the best. This is the
        other half of the duplicate-downloads fix, and it is what makes
        "accept 720p only if no 1080p shows up" work in practice.

      Settings -> Media Management -> Propers and Repacks: "Do Not Prefer"
        Then let the guide's Repack/Proper custom formats handle it by score.
        Leaving the built-in setting enabled puts two mechanisms in charge of
        the same decision, which is how a repack can loop.
  */
  guideProfile =
    { trash_id, until_quality }:
    {
      inherit trash_id;

      min_format_score = 0;
      min_upgrade_format_score = 100; # PLACEHOLDER -- calibrate, see above
      upgrade = {
        allowed = true;
        inherit until_quality;
        until_score = 2000; # PLACEHOLDER -- calibrate, see above
      };
    };

  /*
    Manual-opt-in profile for series that barely exist in HD -- domestic
    free-to-air being the usual case. `WEB-1080p (Alternative)` bottoms out at
    720p, so a show whose only release is an SD rip gets grabbed by nothing at
    all. Switch an individual series to this in Sonarr when that happens.

    Deliberately plainer than the guide profiles: it carries only the unwanted-
    formats scoring, because when a show has one release in existence there is
    nothing for a scoring ladder to choose between. It is a floor, not a ladder.
  */
  sdFallbackName = "WEB-1080p (SD Fallback)";

  sdFallbackProfile = {
    name = sdFallbackName;
    reset_unmatched_scores.enabled = true;

    min_format_score = 0;
    min_upgrade_format_score = 100; # PLACEHOLDER -- calibrate, see above
    upgrade = {
      allowed = true;
      until_quality = "WEB 1080p";
      until_score = 2000; # PLACEHOLDER -- calibrate, see above
    };

    # Mirrors the Alternative profile's ordering, continued down into SD.
    qualities = [
      {
        name = "WEB 1080p";
        qualities = [
          "WEBDL-1080p"
          "WEBRip-1080p"
        ];
      }
      { name = "Bluray-1080p"; }
      { name = "HDTV-1080p"; }
      {
        name = "WEB 720p";
        qualities = [
          "WEBDL-720p"
          "WEBRip-720p"
        ];
      }
      { name = "Bluray-720p"; }
      { name = "HDTV-720p"; }
      {
        name = "WEB 480p";
        qualities = [
          "WEBDL-480p"
          "WEBRip-480p"
        ];
      }
      { name = "Bluray-480p"; }
      { name = "DVD"; }
      { name = "SDTV"; }
    ];
  };

  sonarrSeries = mkInstance "sonarr" {
    include = templates [ "web-1080p-alternative" ];

    quality_profiles = [
      (guideProfile {
        trash_id = "9d142234e45d6143785ac55f5a9e8dc9"; # WEB-1080p (Alternative)
        until_quality = "WEB 1080p";
      })
      sdFallbackProfile
    ];

    # Negative formats the guide ships in this group but leaves off by default.
    custom_format_groups.add = [
      {
        trash_id = "59c3af66780d08332fdc64e68297098f"; # [Unwanted] Unwanted Formats

        # `assign_scores_to` *replaces* the default targeting rather than
        # adding to it, so the guide profile has to be named here too or it
        # silently loses this group's scores. Custom profiles are never
        # targeted by default and must be named explicitly.
        assign_scores_to = [
          { trash_id = "9d142234e45d6143785ac55f5a9e8dc9"; } # WEB-1080p (Alternative)
          { name = sdFallbackName; }
        ];

        select = [
          "82d40da2bc6923f41e14394075dd4b03" # No-RlsGroup
          "e1a997ddb54e3ecbfe06341ad323c458" # Obfuscated
          "06d66ab109d4d2eddb2794d21526d140" # Retags
          "1b3994c551cbb92a2c781af061f4ab44" # Scene
        ];
      }
    ];
  };

  radarrMovies = mkInstance "radarr" {
    include = templates [ "hd-bluray-web" ];

    quality_profiles = [
      (guideProfile {
        trash_id = "d1d67249d3890e49bc12e275d989a7e9"; # HD Bluray + WEB
        until_quality = "Bluray-1080p";
      })
    ];
  };

  radarrMovies4k = mkInstance "radarr4k" {
    include = templates [ "uhd-bluray-web" ];

    quality_profiles = [
      (guideProfile {
        trash_id = "64fb5f9858489bdac2af690e27c8f42f"; # UHD Bluray + WEB
        until_quality = "Bluray-2160p";
      })
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
