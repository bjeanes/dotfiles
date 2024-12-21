{ lib, namespace, ... }:
let
  nas = lib.${namespace}.hosts.nas.zt;
  mounts = {
    media = "/volume1/media";
    docker = "/volume1/docker";
    backups = "/volume1/backups";
  };
  toMount = name: remote-path: {
    type = "nfs";
    mountConfig = {
      Options = "noatime";
    };
    what = "${nas}:${remote-path}";
    where = "/nas/${name}";
  };
  toAutoMount = name: _: {
    wantedBy = [ "multi-user.target" ];
    requires = [ "zerotierone.service" ];
    where = "/nas/${name}";
    automountConfig = {
      TimeoutIdleSec = "600";
    };
  };
in
{
  services.rpcbind.enable = true; # needed for NFS
  boot.supportedFilesystems.nfs = true;

  systemd.automounts = lib.mapAttrsToList toAutoMount mounts;
  systemd.mounts = lib.mapAttrsToList toMount mounts;
}
