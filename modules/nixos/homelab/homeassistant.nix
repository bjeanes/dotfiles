{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.homelab.services.homeassistant;
  nixvirtLib = inputs.nixvirt.lib;

  defaultImageVersion = "17.2";
  defaultImageUrl =
    "https://github.com/home-assistant/operating-system/releases/download/"
    + "${defaultImageVersion}/haos_ova-${defaultImageVersion}.qcow2.xz";

  haosImage = pkgs.fetchurl {
    url = cfg.image.url;
    sha256 = cfg.image.sha256;
  };

  poolDir = cfg.storage.poolDir;
  vmDiskPath = "${poolDir}/${cfg.name}.qcow2";

  backupRoot = "/mnt/nfs/nas/backups";
  backupDir = "${backupRoot}/${cfg.backup.subpath}";
  nfsMountUnit = "mnt-nfs-nas-backups.mount";

  # Stage HAOS image directly as the VM disk on first boot.
  prepareDiskScript = pkgs.writeShellApplication {
    name = "ha-vm-prepare-disk";
    runtimeInputs = with pkgs; [
      qemu_kvm
      coreutils
      xz
    ];
    text = ''
      set -euo pipefail
      mkdir -p "${poolDir}"
      chown root:libvirtd "${poolDir}" || true
      chmod 0775 "${poolDir}" || true

      if [ ! -f "${vmDiskPath}" ]; then
        echo "Staging HAOS image as VM disk..."
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        ${
          if lib.hasSuffix ".xz" cfg.image.url then
            ''xz -dc "${haosImage}" > "$tmp/haos.qcow2"''
          else
            ''cp "${haosImage}" "$tmp/haos.qcow2"''
        }
        echo "Resizing to ${toString cfg.diskSizeGB}G..."
        qemu-img resize "$tmp/haos.qcow2" "${toString cfg.diskSizeGB}G"
        mv "$tmp/haos.qcow2" "${vmDiskPath}"
        chown root:libvirtd "${vmDiskPath}"
        chmod 0664 "${vmDiskPath}"
      fi
    '';
  };

  backupScript = pkgs.writeShellApplication {
    name = "ha-vm-backup";
    runtimeInputs = with pkgs; [
      libvirt
      qemu_kvm
      coreutils
    ];
    text = ''
      set -euo pipefail

      target="${backupDir}"
      if ! mountpoint -q "${backupRoot}"; then
        echo "ERROR: ${backupRoot} is not mounted. Aborting." >&2
        exit 1
      fi
      mkdir -p "$target"

      stamp=$(date -u +%Y%m%dT%H%M%SZ)
      out="$target/${cfg.name}-$stamp.qcow2"

      was_running=0
      if virsh -c qemu:///system domstate ${cfg.name} | grep -q running; then
        was_running=1
        echo "Shutting down ${cfg.name} for consistent backup..."
        virsh -c qemu:///system shutdown ${cfg.name}
        for _ in $(seq 1 60); do
          if ! virsh -c qemu:///system domstate ${cfg.name} | grep -q running; then
            break
          fi
          sleep 2
        done
        if virsh -c qemu:///system domstate ${cfg.name} | grep -q running; then
          echo "Forcing shutdown..."
          virsh -c qemu:///system destroy ${cfg.name}
        fi
      fi

      echo "Copying disk to $out ..."
      qemu-img convert -O qcow2 -c "${vmDiskPath}" "$out.tmp"
      mv "$out.tmp" "$out"

      if [ "$was_running" = "1" ]; then
        echo "Restarting ${cfg.name}..."
        virsh -c qemu:///system start ${cfg.name}
      fi

      keep=${toString cfg.backup.keep}
      mapfile -t backups < <(ls -1t "$target"/${cfg.name}-*.qcow2 2>/dev/null || true)
      if [ "''${#backups[@]}" -gt "$keep" ]; then
        for f in "''${backups[@]:$keep}"; do
          echo "Pruning old backup: $f"
          rm -f "$f"
        done
      fi

      echo "Backup complete: $out"
    '';
  };

  restoreScript = pkgs.writeShellApplication {
    name = "ha-vm-restore";
    runtimeInputs = with pkgs; [
      libvirt
      qemu_kvm
      coreutils
      gnused
    ];
    text = ''
      set -euo pipefail

      target="${backupDir}"
      if ! mountpoint -q "${backupRoot}"; then
        echo "ERROR: ${backupRoot} is not mounted." >&2
        exit 1
      fi

      usage() {
        cat <<EOF
      Usage: ha-vm-restore [--list | <backup-file>]

        --list             Show available backups, newest first.
        <backup-file>      Path or basename of backup to restore.
                           Basenames are resolved relative to $target.

      Restoring will:
        1. Shut down the ${cfg.name} VM (forcefully if needed).
        2. Replace ${vmDiskPath} with the chosen backup.
        3. Start the VM.

      The UEFI nvram file is preserved; only the qcow2 disk is replaced.
      You will be prompted for confirmation before any destructive step.
      EOF
      }

      if [ $# -eq 0 ]; then
        usage; exit 1
      fi

      if [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
        echo "Available backups in $target:"
        echo
        if ! ls -1t "$target"/${cfg.name}-*.qcow2 2>/dev/null; then
          echo "  (none)"
          exit 1
        fi
        exit 0
      fi

      if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        usage; exit 0
      fi

      src="$1"
      if [ ! -f "$src" ]; then
        if [ -f "$target/$src" ]; then
          src="$target/$src"
        else
          echo "ERROR: backup file not found: $1" >&2
          echo "Try: ha-vm-restore --list" >&2
          exit 1
        fi
      fi

      if ! qemu-img info "$src" >/dev/null 2>&1; then
        echo "ERROR: $src does not appear to be a valid qemu image." >&2
        exit 1
      fi

      echo
      echo "About to RESTORE ${cfg.name} from:"
      echo "    $src"
      echo "This will REPLACE the live disk at:"
      echo "    ${vmDiskPath}"
      echo "The current disk will be saved as:"
      echo "    ${vmDiskPath}.pre-restore-$(date -u +%Y%m%dT%H%M%SZ)"
      echo
      read -r -p "Proceed? Type 'yes' to confirm: " confirm
      if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 1
      fi

      was_running=0
      if virsh -c qemu:///system domstate ${cfg.name} | grep -q running; then
        was_running=1
        echo "Shutting down ${cfg.name}..."
        virsh -c qemu:///system shutdown ${cfg.name} || true
        for _ in $(seq 1 60); do
          if ! virsh -c qemu:///system domstate ${cfg.name} | grep -q running; then
            break
          fi
          sleep 2
        done
        if virsh -c qemu:///system domstate ${cfg.name} | grep -q running; then
          echo "Forcing shutdown..."
          virsh -c qemu:///system destroy ${cfg.name}
        fi
      fi

      preserved="${vmDiskPath}.pre-restore-$(date -u +%Y%m%dT%H%M%SZ)"
      if [ -f "${vmDiskPath}" ]; then
        echo "Preserving current disk to $preserved"
        mv "${vmDiskPath}" "$preserved"
      fi

      echo "Copying backup into place..."
      cp --reflink=auto "$src" "${vmDiskPath}.tmp"
      chown root:libvirtd "${vmDiskPath}.tmp"
      chmod 0664 "${vmDiskPath}.tmp"
      mv "${vmDiskPath}.tmp" "${vmDiskPath}"

      echo "Starting ${cfg.name}..."
      virsh -c qemu:///system start ${cfg.name}

      echo
      echo "Restore complete."
      echo "Previous disk preserved at: $preserved"
      echo "Remove it manually once you've verified the restore is healthy."
      if [ "$was_running" = "0" ]; then
        echo "(VM was not running before restore; started it anyway.)"
      fi
    '';
  };

  # ---- nixvirt domain via the linux template ----
  # USB IDs are hex strings on the option for ergonomics; convert to int
  # for nixvirt's schema (which expects integer vendor/product IDs).
  usbHostdev = dev: {
    mode = "subsystem";
    type = "usb";
    managed = true;
    source = {
      vendor = {
        id = lib.fromHexString dev.vendorId;
      };
      product = {
        id = lib.fromHexString dev.productId;
      };
    };
  };

  netInterface =
    if cfg.network.mode == "macvtap" then
      {
        type = "direct";
        source = {
          dev = cfg.network.hostInterface;
          mode = "bridge";
        };
        model = {
          type = "virtio";
        };
      }
      // lib.optionalAttrs (cfg.network.macAddress != null) {
        mac = {
          address = cfg.network.macAddress;
        };
      }
    else if cfg.network.mode == "bridge" then
      {
        type = "bridge";
        source = {
          bridge = cfg.network.hostInterface;
        };
        model = {
          type = "virtio";
        };
      }
      // lib.optionalAttrs (cfg.network.macAddress != null) {
        mac = {
          address = cfg.network.macAddress;
        };
      }
    else
      {
        type = "network";
        source = {
          network = "default";
        };
        model = {
          type = "virtio";
        };
      };

  baseDomain = nixvirtLib.domain.templates.linux {
    name = cfg.name;
    uuid = cfg.uuid;
    vcpu = {
      count = cfg.vcpus;
    };
    memory = {
      count = cfg.memoryMB;
      unit = "MiB";
    };
    virtio_video = false;
  };

  domainDef = baseDomain // {
    os = {
      type = "hvm";
      arch = "x86_64";
      machine = "q35";
      loader = {
        readonly = true;
        type = "pflash";
        path = "${pkgs.OVMFFull.fd}/FV/OVMF_CODE.fd";
      };
      nvram = {
        template = "${pkgs.OVMFFull.fd}/FV/OVMF_VARS.fd";
        path = "/var/lib/libvirt/qemu/nvram/${cfg.name}_VARS.fd";
      };
    };
    devices = baseDomain.devices // {
      controller = [
        {
          type = "scsi";
          index = 0;
          model = "virtio-scsi";
        }
      ];
      disk = [
        {
          type = "file";
          source = {
            file = vmDiskPath;
          };
          target = {
            dev = "sda";
            bus = "scsi";
          };
          driver = {
            name = "qemu";
            type = "qcow2";
          };
          boot = {
            order = 1;
          };
        }
      ];
      interface = [ netInterface ];
      hostdev = map usbHostdev cfg.usbDevices;
      console = [
        {
          type = "pty";
          target = {
            type = "serial";
            port = 0;
          };
        }
      ];
    };
  };

  poolDef = {
    type = "dir";
    name = cfg.storage.poolName;
    target = {
      path = poolDir;
    };
  };

  baseXml = nixvirtLib.domain.writeXML domainDef;

  # Workaround lack of support for <serial type="dev"> in NixVirt's XML schema (does not output the `<source>`)
  #
  # Use a Python script for the splice — sed/awk on XML is fragile
  # because of escaping, but a tiny ElementTree script is robust.
  patchScript =
    pkgs.writers.writePython3 "patch-domain-xml"
      {
        flakeIgnore = [ "E501" ];
      }
      /* python */ ''
        import json
        import sys
        import xml.etree.ElementTree as ET

        base_xml = sys.argv[1]
        output = sys.argv[2]
        paths = json.loads(sys.argv[3])

        tree = ET.parse(base_xml)
        devices = tree.getroot().find("devices")

        # Remove the existing PTY console — we'll re-add it below with explicit
        # port to keep it from being hijacked by the first serial passthrough.
        for c in devices.findall("console"):
            devices.remove(c)

        # Add an explicit PTY serial + matching console at port 0.
        # This preserves `virsh console <domain>` access.
        pty_serial = ET.SubElement(devices, "serial", {"type": "pty"})
        ET.SubElement(pty_serial, "target", {"type": "isa-serial", "port": "0"})

        pty_console = ET.SubElement(devices, "console", {"type": "pty"})
        ET.SubElement(pty_console, "target", {"type": "serial", "port": "0"})

        # Add passthrough serials at port 1, 2, ...
        for i, path in enumerate(paths):
            serial = ET.SubElement(devices, "serial", {"type": "dev"})
            ET.SubElement(serial, "source", {"path": path})
            ET.SubElement(serial, "target", {"port": str(i + 1)})

        tree.write(output)
      '';

  domainXml =
    if cfg.serialDevices == [ ] then
      baseXml
    else
      pkgs.runCommand "${cfg.name}-domain.xml" { } ''
        ${patchScript} ${baseXml} $out ${lib.escapeShellArg (builtins.toJSON cfg.serialDevices)}
      '';

in
{
  options.homelab.services.homeassistant = {
    enable = lib.mkEnableOption "Home Assistant OS VM, declaratively via nixvirt";

    name = lib.mkOption {
      type = lib.types.str;
      default = "homeassistant";
      description = "libvirt domain name.";
    };

    uuid = lib.mkOption {
      type = lib.types.str;
      example = "c58ee3e9-7989-4c87-a30c-8df7f5c8871f";
      description = ''
        Stable libvirt UUID for the domain. Generate once with `uuidgen`
        and commit it — keeping this stable across rebuilds avoids
        libvirt seeing a "different VM with the same name" on every
        deploy.
      '';
    };

    vcpus = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
    };

    memoryMB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4096;
    };

    diskSizeGB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 32;
      description = ''
        Disk size used when initially staging the HAOS image. Only takes
        effect on first provisioning.
      '';
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    image = {
      version = lib.mkOption {
        type = lib.types.str;
        default = defaultImageVersion;
      };
      url = lib.mkOption {
        type = lib.types.str;
        default = defaultImageUrl;
      };
      sha256 = lib.mkOption {
        type = lib.types.str;
        default = lib.fakeSha256;
      };
    };

    storage = {
      poolDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/libvirt/images";
      };
    };

    network = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "macvtap"
          "bridge"
          "nat"
        ];
        default = "macvtap";
      };
      hostInterface = lib.mkOption {
        type = lib.types.str;
        default = "eno1";
      };
      macAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "52:54:00:12:34:56";
      };
    };

    usbDevices = lib.mkOption {
      default = [ ];
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            vendorId = lib.mkOption {
              type = lib.types.strMatching "(0[xX])?[0-9a-fA-F]{4}";
              description = "USB vendor ID, 4 hex digits, no 0x prefix.";
            };
            productId = lib.mkOption {
              type = lib.types.strMatching "(0[xX])?[0-9a-fA-F]{4}";
              description = "USB product ID, 4 hex digits, no 0x prefix.";
            };
          };
        }
      );
      example = [
        {
          vendorId = "10c4";
          productId = "ea60";
        }
      ];
    };

    serialDevices = lib.mkOption {
      default = [ ];
      description = ''
        Host serial/character devices to expose to the guest as serial ports.
        Use this as an alternative to USB passthrough for devices where USB
        emulation causes timing issues (e.g. Conbee II / deCONZ firmware).

        Inside the guest these appear as additional serial ports
        (`/dev/ttyS1`, `/dev/ttyS2`, ...) in the order listed here.
      '';
      example = [
        "/dev/serial/by-id/usb-dresden_elektronik_ingenieurtechnik_GmbH_ConBee_II_DE2419104-if00"
      ];
      type = lib.types.listOf lib.types.str;
    };

    backup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable scheduled disk-level backups via the
          `${nfsMountUnit}` mount unit. Backups land under
          ${backupRoot}/<subpath>/.
        '';
      };
      subpath = lib.mkOption {
        type = lib.types.str;
        default = "homeassistant";
      };
      schedule = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
      };
      keep = lib.mkOption {
        type = lib.types.ints.positive;
        default = 8;
      };
      randomizedDelaySec = lib.mkOption {
        type = lib.types.str;
        default = "1h";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    virtualisation.libvirt = {
      enable = true;
      verbose = true;
      swtpm.enable = false;
      connections."qemu:///system" = {
        networks = [ ];
        pools = [ ];
        domains = [
          {
            definition = domainXml;
            active = cfg.autostart;
          }
        ];
      };
    };

    virtualisation.libvirtd = {
      onShutdown = "shutdown";
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
      };
    };

    environment.systemPackages = with pkgs; [
      virt-manager
      libvirt
      qemu_kvm
      restoreScript
    ];

    boot.kernelModules = lib.mkIf (cfg.network.mode == "macvtap") [
      "macvtap"
      "macvlan"
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.storage.poolDir} 0775 root libvirtd -"
      "d /var/lib/libvirt/qemu/nvram 0770 root libvirtd -"
    ];

    systemd.services."ha-vm-prepare" = {
      description = "Prepare Home Assistant VM disk image";
      after = [ "libvirtd.service" ];
      requires = [ "libvirtd.service" ];
      before = [ "nixvirt.service" ];
      wantedBy = [ "nixvirt.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${prepareDiskScript}/bin/ha-vm-prepare-disk";
      };
    };

    systemd.services."ha-vm-backup" = lib.mkIf cfg.backup.enable {
      description = "Back up Home Assistant VM disk to NAS";
      requires = [ nfsMountUnit ];
      after = [ nfsMountUnit ];
      bindsTo = [ nfsMountUnit ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${backupScript}/bin/ha-vm-backup";
        TimeoutStartSec = "1h";
      };
    };

    systemd.timers."ha-vm-backup" = lib.mkIf cfg.backup.enable {
      description = "Periodic Home Assistant VM backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.backup.schedule;
        Persistent = true;
        RandomizedDelaySec = cfg.backup.randomizedDelaySec;
      };
    };
  };
}
