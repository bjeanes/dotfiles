# TODO: can I put the containers in a systemd slice, have the slice depend on the Podman pod and clean it up when slice stops?
{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
with lib;
let
  svc = "immich";
  version = "1.123.0";
in
{
  options.homelab.services.${svc} = {
    enable = mkEnableOption svc;
    configDir = mkOption {
      default = "/var/lib/homelab/${svc}";
      example = "/var/lib/homelab/${svc}";
      type = types.str;
      description = "Location to store ${svc} config";
    };
  };
  config =
    let
      cfg = config.homelab.services.${svc};
      myLib = lib.${namespace};
      svcName = myLib.containerSvcName config svc;
      setEnvFromCommandsForContainer = myLib.setEnvFromCommandsForContainer config;
    in
    mkIf cfg.enable (mkMerge [
      {
        virtualisation.oci-containers.backend = mkForce "podman"; # we're trying Podman Pods here, so we _have_ to be running under Podman

        virtualisation.oci-containers.containers = {
          ${svc} = {
            image = "ghcr.io/immich-app/immich-server:v${version}";
            dependsOn = [
              "${svc}-db"
              "${svc}-redis"
              "${svc}-ml"
            ];
            environment = {
              REDIS_HOSTNAME = "localhost";
              DB_HOSTNAME = "localhost";
              UPLOAD_LOCATION = "/nas/media/Photos";
            };
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "/nas/media/Photos:/usr/src/app/upload"
              # "/var/services/homes/bjeanes/Google Drive/Google Photos:/media/bo/gphotos"
              # "/var/services/homes/bjeanes/Drive/Moments:/media/bo/moments"
            ];
          };

          "${svc}-db" = {
            image = "tensorchord/pgvecto-rs:pg14-v0.2.0@sha256:90724186f0a3517cf6914295b5ab410db9ce23190a2d9d0b9dd6463e3fa298f0";
            command = ''
              postgres
              -c shared_preload_libraries=vectors.so
              -c 'search_path="$$user", public, vectors'
              -c logging_collector=on
              -c max_wal_size=2GB
              -c shared_buffers=512MB
              -c wal_compression=on
            '';

          };
          "${svc}-redis".image =
            "redis:6.2-alpine@sha256:905c4ee67b8e0aa955331960d2aa745781e6bd89afc44a8584bfd13bc890f0a";

          "${svc}-ml" = {
            image = "ghcr.io/immich-app/immich-machine-learning:v${version}";
            devices = [
              "/dev/dri:/dev/dri"
            ];
          };

          "${svc}-tailscale" = { };
        };

        systemd.services."create-${svc}-pod" =
          let
            podman = config.virtualisation.podman.package;
          in
          {
            serviceConfig.Type = "oneshot";
            wantedBy = [
              "${svc}.service"
              "${svc}-redis.service"
              "${svc}-ml.service"
              "${svc}-db.service"
            ];
            script = ''
              ${podman}/bin/podman pod exists ${svc} || ${podman}/bin/podman pod create -n ${svc}
            '';
          };

        systemd.services."podman-${svc}" = {
          aliases = [ "${svc}.service" ];
          after = [ "nas-media.automount" ];
          upheldBy = [
            "nas-media.automount"
            "podman-${svc}-db.service"
            "podman-${svc}-redis.service"
          ];
        };
        systemd.services."podman-${svc}-db".aliases = [ "${svc}-db.service" ];
        systemd.services."podman-${svc}-redis".aliases = [ "${svc}-redis.service" ];
        systemd.services."podman-${svc}-ml".aliases = [
          "${svc}-ml.service"
          "${svc}-machine-learning.service"
        ];
      }

      (lib.mkIf cfg.backupToNAS {
        systemd.services."backup-${name}-to-NAS" = {
          requires = [ "nas-docker.mount" ];
          after = [ "nas-docker.mount" ];
          startAt = "*-*-* 02:00:00 ${cfg.timeZone}";
          serviceConfig = {
            Type = "oneshot";
          };
          script = ''
            set -eu
            ${pkgs.util-linux}/bin/flock /tmp/backup-to-NAS.lock \
              ${pkgs.rsync}/bin/rsync -avuP --no-o --no-g ${lib.escapeShellArg cfg.configDir}/* /nas/docker/immich/
          '';
        };
      })
    ]);
}
