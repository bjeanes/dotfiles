{
  lib,
  namespace,
  pkgs,
  ...
}:
let
  nas = lib.${namespace}.hosts.nas.lan;
  mountModules =
    from: at: mounts:
    (lib.mapAttrsToList (name: remote-path: {
      systemd.mounts = [
        {
          aliases = [ "${at}-${name}.mount" ];
          type = "nfs";
          mountConfig = {
            Options = "rw,noatime,timeo=30,retrans=3,soft,retry=3";
          };
          what = "${from}:${remote-path}";
          where = "/mnt/nfs/${at}/${name}";
        }
      ];

      systemd.automounts = [
        {
          wantedBy = [ "multi-user.target" ];
          where = "/mnt/nfs/${at}/${name}";
          automountConfig = {
            TimeoutIdleSec = "600";
          };
        }
      ];
    }) mounts);
  mergerfsModule =
    where: mounts:
    let
      what = lib.concatStringsSep ":" mounts;
      deps = (lib.map (p: "x-systemd.requires-mounts-for=${p}") mounts);
    in
    {
      environment.systemPackages = with pkgs; [
        mergerfs
      ];

      systemd.mounts = [
        {
          inherit where what;
          type = "fuse.mergerfs";
          mountConfig = {
            Options = lib.concatStringsSep "," (
              [
                "defaults"
                "cache.files=off"
                "dropcacheonclose=true"
                "allow_other"
                "nofail"
                "uid=1024" # NFS squashes to this UID, but MergerFS has a fuss without this
                "gid=100" # NFS squashes to this GID, but MergerFS has a fuss without this
              ]
              ++ deps
            );
          };
        }
      ];

      systemd.automounts = [
        {
          inherit where;
          wantedBy = [ "multi-user.target" ];
        }
      ];

    };
in
{
  imports =
    (mountModules lib.${namespace}.hosts.nas.lan "nas" {
      media = "/volume1/media";
      docker = "/volume1/docker";
      backups = "/volume1/backups";
    })
    ++ (mountModules "10.10.10.14" "tempnas" {
      media = "/volume2/slow";
      docker = "/volume2/docker";
      backups = "/volume1/backups";
    })
    ++ [
      (mergerfsModule "/mnt/merged/media" [
        "/mnt/nfs/nas/media"
        "/mnt/nfs/tempnas/media"
      ])
      (mergerfsModule "/mnt/merged/docker" [
        "/mnt/nfs/nas/docker"
        "/mnt/nfs/tempnas/docker"
      ])
      (mergerfsModule "/mnt/merged/backups" [
        "/mnt/nfs/nas/backups"
        "/mnt/nfs/tempnas/backups"
      ])
    ];

  config = {
    services.rpcbind.enable = true; # needed for NFS
    boot.supportedFilesystems.nfs = true;
  };
}
