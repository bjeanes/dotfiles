{ lib, namespace, ... }:
rec {
  containerSvcName = config: name: "${config.virtualisation.oci-containers.backend}-${name}";

  # Allow setting environment variables on an oci-container declaration from the contents of a file
  setEnvFromFilesForContainer =
    config: name: vars:
    setEnvFromCommandsForContainer config name (
      builtins.mapAttrs (_: v: "cat ${lib.escapeShellArg v}") vars
    );

  # Allow setting environment variables on an oci-container declaration from the output of a command
  setEnvFromCommandsForContainer =
    config: name: vars: with lib; {
      # Add `-e VAR` to add var to container from context environment
      virtualisation.oci-containers.containers.${name}.extraOptions = map (n: "-e=${escapeShellArg n}") (
        builtins.attrNames vars
      );

      systemd.services."${containerSvcName config name}".script = mkBefore (
        concatStringsSep "\n" (mapAttrsToList (k: cmd: ''export ${escapeShellArg k}="$(${cmd})"'') vars)
      );
    };
}
