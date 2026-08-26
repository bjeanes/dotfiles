{
  lib,
  namespace,
  ...
}:
let
  myLib = lib.${namespace};
  inherit (myLib) mkTailscaleContainerCommon mkTaildriveShares;
in
rec {
  containerSvcName =
    config: name: config.virtualisation.oci-containers.containers.${name}.serviceName;

  # Allow setting environment variables on an oci-container declaration from the contents of a file
  setEnvFromFilesForContainer =
    pkgs: config: name: vars:
    setEnvFromCommandsForContainer pkgs config name (
      builtins.mapAttrs (_: v: "cat ${lib.escapeShellArg v}") vars
    );

  # Allow setting environment variables on an oci-container declaration from the output of a command
  setEnvFromCommandsForContainer =
    pkgs: config: containerName: variables:
    mkOciDynamicEnvironment pkgs config { inherit variables containerName; };

  mkOciDynamicEnvironment =
    pkgs: config:
    {
      containerName,
      variables,
    }:
    let
      serviceName = containerSvcName config containerName;

      generated = mkDynamicEnvFile pkgs {
        inherit serviceName variables;
      };
    in
    {
      virtualisation.oci-containers.containers.${containerName}.environmentFiles = [
        generated.envFile
      ];

      systemd.services.${serviceName}.serviceConfig = {
        ExecStartPre = lib.mkAfter [ generated.execStartPre ];
        ExecStopPost = lib.mkAfter [ generated.execStopPost ];
      };
    };

  mkQuadletDynamicEnvironment =
    pkgs: config:
    {
      containerName,
      variables,
    }:
    let
      serviceName = "${containerName}.service";

      generated = mkDynamicEnvFile pkgs {
        inherit serviceName variables;
      };
    in
    {
      virtualisation.quadlet.containers.${containerName} = {
        containerConfig.environmentFiles = [
          generated.envFile
        ];

        serviceConfig = {
          RuntimeDirectory = lib.mkDefault containerName;
          ExecStartPre = lib.mkAfter [ generated.execStartPre ];
          ExecStopPost = lib.mkAfter [ generated.execStopPost ];
        };
      };
    };

  mkDynamicEnvFile =
    pkgs:
    {
      serviceName,
      variables,
      fragmentName ? lib.concatStringsSep "-" (builtins.attrNames variables),
    }:
    let
      publicDirectory = "/run/dynamic-container-env/${serviceName}";

      # Inside the script which generates the env, $RUNTIME_DIRECTORY will be
      # set by systemd, but in order to configure podman to use the env file,
      # a statically known name must be used. We use a symlink to the runtime
      # location so that systemd can clean up the real file. This will leave
      # a dangling symlink but it will at least not leave behind the file
      # contents (which might contain secrets).
      envFileSymlink = "${publicDirectory}/${fragmentName}.env";

      clean = (
        pkgs.writeShellScript "cleanup-${serviceName}-env" ''
          set -euo pipefail

          rm -f ${lib.escapeShellArg envFileSymlink}
          rmdir --ignore-fail-on-non-empty ${lib.escapeShellArg publicDirectory}
        ''
      );

      generate = pkgs.writeShellScript "generate-${serviceName}-${fragmentName}-env" /* bash */ ''
        set -euo pipefail

        realEnvFile="$RUNTIME_DIRECTORY/${fragmentName}.env"

        ${pkgs.coreutils}/bin/install \
          -d \
          -m 0700 \
          ${lib.escapeShellArg publicDirectory}

        tmp="$(${pkgs.coreutils}/bin/mktemp $RUNTIME_DIRECTORY/.${lib.escapeShellArg fragmentName}.XXXXX)"

        cleanup() {
          rm -f "$tmp"
        }
        trap cleanup EXIT

        ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (variable: command: /* bash */ ''
            value="$(
              ${command}
            )"

            # Podman env files are line-oriented. Reject values that
            # cannot be represented unambiguously.
            case "$value" in
              *$'\n'*)
                echo Dynamic environment variable ${lib.escapeShellArg variable} contains a newline >&2
                exit 1
                ;;
            esac

            printf '%s=%s\n' \
              ${lib.escapeShellArg variable} \
              "$value" \
              >> "$tmp"
          '') variables
        )}

        ${pkgs.coreutils}/bin/chmod 0600 "$tmp"
        ${pkgs.coreutils}/bin/mv -f "$tmp" "$realEnvFile"
        trap - EXIT

        ${pkgs.coreutils}/bin/ln -sfn "$realEnvFile" ${lib.escapeShellArg envFileSymlink}
      '';
    in
    {
      envFile = envFileSymlink;
      execStartPre = generate;
      execStopPost = clean;
    };

  mkTailscaleContainer =
    pkgs: config: name:
    {
      container ? { },
      ...
    }@opts:
    with lib;
    let
      rest = removeAttrs opts [ "container" ];
      common = mkTailscaleContainerCommon pkgs config name rest;
    in
    mkMerge [
      common.config
      {
        virtualisation.oci-containers.containers.${name} = container;
      }
      (mkOciDynamicEnvironment pkgs config {
        containerName = name;
        variables = common.dynamicEnvironment;
      })
      {
        virtualisation.oci-containers.containers.${name} = {
          inherit (common)
            environment
            volumes
            image
            hostname
            ;
          extraOptions = [
            "--cap-add=net_admin"
            "--cap-add=sys_module"
          ]
          ++ common.extraOptions;
          labels = {
            "io.containers.autoupdate" = "registry";
          };
        };
      }
      (mkTaildriveShares pkgs {
        containerName = name;
        unit = "${containerSvcName config name}.service";
        shares = common.driveShares;
        ctr =
          let
            inherit (config.virtualisation.oci-containers) backend;
          in
          "${pkgs.${backend}}/bin/${backend}";
      })
    ];

  mkTailscaleQuadletContainer =
    pkgs: config: name:
    {
      podName ? "${name}-pod",
      pod ? config.virtualisation.quadlet.pods.${podName}.ref,
      ...
    }@opts:
    with lib;
    let
      rest = removeAttrs opts [
        "pod"
        "podName"
      ];
      common = mkTailscaleContainerCommon pkgs config name rest;
    in
    mkMerge [
      common.config

      (mkQuadletDynamicEnvironment pkgs config {
        containerName = name;
        variables = common.dynamicEnvironment;
      })

      {
        virtualisation.quadlet.containers.${name} = {
          autoStart = true;
          containerConfig = {
            inherit (common) image volumes;
            inherit pod;
            autoUpdate = "registry";
            environments = common.environment;
            addCapabilities = [
              "NET_ADMIN"
              "SYS_MODULE"
            ];
            # `User=`; the passwd entry it resolves against has no quadlet key
            user = common.user;
            podmanArgs = optionals (common.user != null) [ "--hostuser=${common.user}" ];
          };
        };
      }
      (mkTaildriveShares pkgs {
        containerName = name;
        unit = "${name}.service";
        shares = common.driveShares;
      })
    ];

}
