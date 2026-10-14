{ flake, lib, ... }:
{
  # Options every `homelab.services.<svc>` shares. Anything service-specific,
  # including overriding one of these, goes on with `//`.
  mkHomelabServiceOptions =
    config: svc:
    {
      description ? "Enable ${svc}",
      # `null` omits the option
      image ? null,
      # `null` omits the option; otherwise the default tailnet hostname
      hostName ? null,
      withUser ? false,
      backupDescription ? "Back up configDir to legacy location on NAS",
    }:
    {
      enable = lib.mkOption {
        default = false;
        type = lib.types.bool;
        inherit description;
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

      backupToNAS = lib.mkOption {
        default = true;
        type = lib.types.bool;
        description = backupDescription;
      };
    }
    // lib.optionalAttrs (image != null) {
      image = lib.mkOption {
        default = image;
        type = lib.types.str;
        description = "OCI image for ${svc}";
      };
    }
    // lib.optionalAttrs (hostName != null) {
      hostName = lib.mkOption {
        default = hostName;
        type = lib.types.str;
        description = "Tailnet hostname to expose ${svc} as";
      };
    }
    // lib.optionalAttrs withUser {
      user = lib.mkOption {
        default = flake.lib.coalesce config.homelab.user svc;
        type = lib.types.str;
        description = "User to run ${svc} service as";
      };

      group = lib.mkOption {
        default = config.homelab.group;
        type = lib.types.str;
        description = "Group to run the ${svc} service as";
      };
    };

  # A path option defaulting to the agenix secret `<svc>-<secret>`
  mkSecretFileOption =
    config: svc: secret: description:
    lib.mkOption {
      default = config.age.secrets."${svc}-${secret}".path;
      type = lib.types.str;
      inherit description;
    };
}
