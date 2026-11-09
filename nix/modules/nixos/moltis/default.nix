{
  config,
  lib,
  pkgs,
  perSystem,
  ...
}:
let
  cfg = config.services.moltis;
  stateDir = "/var/lib/moltis";
  toml = pkgs.formats.toml { };
in
{
  options.services.moltis = {
    enable = lib.mkEnableOption "the Moltis agent server";

    package = lib.mkOption {
      type = lib.types.package;
      default = perSystem.self.moltis;
    };

    bind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 13131;
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        MOLTIS_BEHIND_PROXY = "true";
      };
    };

    credentials = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      example = {
        OPENROUTER_API_KEY = "/run/agenix/openrouter-api-key";
      };
      description = ''
        Environment variables to set, each from the contents of its own file,
        such as provider API keys. Since systemd reads each file before
        dropping privileges, the files can stay readable by root alone.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.chromium ]";
      description = ''
        Packages on Moltis's PATH, such as browsers for its browser tool in
        sessions that aren't sandboxed.
      '';
    };

    podman.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run Moltis's tool sandbox in rootless Podman. This turns off
        `NoNewPrivileges` for the service, so that Podman can use the setuid
        `newuidmap`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.moltis = {
      isSystemUser = true;
      group = "moltis";
      home = stateDir;
      autoSubUidGidRange = cfg.podman.enable;
    };
    users.groups.moltis = { };

    virtualisation.podman.enable = lib.mkIf cfg.podman.enable true;

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.moltis = {
      description = "Moltis agent server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      path =
        lib.optionals cfg.podman.enable [
          "/run/wrappers"
          config.virtualisation.podman.package
        ]
        ++ cfg.extraPackages;

      environment = {
        MOLTIS_DATA_DIR = stateDir;
        MOLTIS_CONFIG_DIR = "${stateDir}/config";
        HOME = stateDir;
      }
      // lib.optionalAttrs cfg.podman.enable {
        XDG_RUNTIME_DIR = "/run/moltis";
        CONTAINERS_CONF_OVERRIDE = toml.generate "moltis-containers.conf" {
          engine.cgroup_manager = "cgroupfs";
        };
        CONTAINERS_REGISTRIES_CONF = toml.generate "moltis-registries.conf" {
          unqualified-search-registries = [ "docker.io" ];
        };
      }
      // cfg.environment;

      script = ''
        ${lib.concatMapStrings (name: ''
          ${name}=$(< "$CREDENTIALS_DIRECTORY/${name}")
          export ${name}
        '') (lib.attrNames cfg.credentials)}
        exec ${lib.getExe cfg.package} gateway \
          --bind ${lib.escapeShellArg cfg.bind} \
          --port ${toString cfg.port} \
          --no-tls \
          --no-open-browser
      '';

      serviceConfig = {
        User = "moltis";
        Group = "moltis";
        StateDirectory = [
          "moltis"
          "moltis/config"
        ];
        StateDirectoryMode = "0700";
        LoadCredential = lib.mapAttrsToList (name: path: "${name}:${path}") cfg.credentials;
        Restart = "on-failure";
        RestartSec = 5;

        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        # Rootless Podman maps its user namespace through the setuid newuidmap
        NoNewPrivileges = !cfg.podman.enable;
      }
      // lib.optionalAttrs cfg.podman.enable {
        RuntimeDirectory = "moltis";
        RuntimeDirectoryMode = "0700";
        Delegate = true;
      };
    };
  };
}
