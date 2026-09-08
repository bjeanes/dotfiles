# Google Pixel Slate (board codename "nocturne"), Amber Lake Y, 12.3" 3000x2000
# touchscreen. Stock ChromeOS firmware replaced with MrChromebox coreboot+edk2,
# so this behaves as an ordinary UEFI x86_64 machine.

# See https://github.com/kabili207/nocturne-linux for prior art on configuring
# Linux for this device.
#
# Intended role: wall-mounted Home Assistant dashboard / kiosk.
#
{
  config,
  inputs,
  lib,
  namespace,
  pkgs,
  system,
  ...
}:
let
  # The dashboard the kiosk session opens on.
  dashboardUrl = "http://${lib.${namespace}.hosts.homeassistant.lan}:8123/";

  # Leave true while hardware is still being sorted (audio, rotation, touch);
  # flip to false for the bare kiosk session.
  desktop = false;

  nocturne = inputs.nocturne-linux;

  # AVS DSP firmware and topology blobs, extracted from ChromeOS. Paths mirror
  # what the driver looks for: /lib/firmware/intel/avs/{,skl/}*.bin
  avsFirmware = pkgs.runCommand "nocturne-avs-firmware" { } ''
    mkdir -p $out/lib/firmware/intel/avs/skl
    cp ${nocturne}/config/firmware/avs/*.bin $out/lib/firmware/intel/avs/
    cp ${nocturne}/config/firmware/avs/skl/*.bin $out/lib/firmware/intel/avs/skl/
  '';

  # WirePlumber needs a headroom bump and a volume limit for these speakers.
  # (53-device-names.conf exists upstream but setup.sh doesn't install it.)
  wirePlumberConfig = pkgs.runCommand "nocturne-wireplumber-config" { } ''
    d=$out/share/wireplumber/wireplumber.conf.d
    mkdir -p "$d"
    cp ${nocturne}/config/wireplumber/51-increase-headroom.conf "$d/"
    cp ${nocturne}/config/wireplumber/52-volume-limit.conf "$d/"
  '';

  swayConfig = pkgs.writeText "tulgey-kiosk.conf" ''
    output eDP-1 scale 2

    default_border none
    default_floating_border none
    xwayland disable

    # No idle handling, no lock screen: this is a wall panel.
    exec ${lib.getExe pkgs.chromium} \
      --kiosk \
      --app=${dashboardUrl} \
      --ozone-platform=wayland \
      --noerrdialogs \
      --disable-infobars \
      --disable-features=TranslateUI
  '';

  # Toggle the panel backlight. Writes bl_power (the standard sysfs blanking
  # control) and zeroes brightness as a belt-and-braces measure, since not
  # every driver honours bl_power. There is only one backlight on this board,
  # so a single state file is fine.
  toggleDisplay = pkgs.writeShellScript "toggle-display" ''
    set -u
    state=/run/panel-brightness
    if [ -e "$state" ]; then
      for bl in /sys/class/backlight/*; do
        echo 0 >"$bl/bl_power" 2>/dev/null || true
        cat "$state" >"$bl/brightness" 2>/dev/null || true
      done
      rm -f "$state"
    else
      for bl in /sys/class/backlight/*; do
        cat "$bl/brightness" >"$state" 2>/dev/null || true
        echo 4 >"$bl/bl_power" 2>/dev/null || true
        echo 0 >"$bl/brightness" 2>/dev/null || true
      done
    fi
  '';
in
{
  snowfallorg.users.bjeanes = { };

  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ChromeOS-era hardware wants a recent kernel: cros_ec drivers for the
  # embedded controller and its sensors, and the Intel AVS audio driver.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  time.timeZone = "Australia/Melbourne";

  networking.hostId = "ead7048e";
  networking.networkmanager.enable = true;

  users.users.bjeanes = {
    isNormalUser = true;
    group = "users";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    shell = pkgs.zsh;
    hashedPasswordFile = config.age.secrets.default-password.path;
  };

  services.glances = {
    enable = true;
    openFirewall = true;
  };

  hardware.graphics.enable = true;

  # Touchscreen and the detachable's touchpad both come up under libinput.
  services.libinput.enable = true;

  # The embedded controller exposes cros-ec-accel, cros-ec-gyro and
  # cros-ec-light (plus an acpi-als), for rotation, ambient light, etc.
  hardware.sensor.iio.enable = true;

  # --- Audio ---------------------------------------------------------------
  # The Intel AVS driver binds on its own (cards enumerate as AVS DMIC /
  # AVS I2S MAX98373 / AVS HDMI) but produces no sound without the ChromeOS
  # DSP firmware, a UCM2 profile, and these module options. `ignore_fw_version`
  # is required because the extracted blobs don't match the version the driver
  # expects.
  #
  # NOTE: speakers may still not work until the firmware carries the coreboot
  # NHLT 32-bit-render-format fix -- see nocturne.md, "Audio".
  boot.extraModprobeConfig = builtins.readFile "${nocturne}/config/modprobe/snd-avs.conf";

  hardware.firmware = [ avsFirmware ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.configPackages = [ wirePlumberConfig ];
  };

  # The UCM2 profile isn't upstream, so overlay it onto alsa-ucm-conf where
  # alsa-lib will find it, rather than fiddling with ALSA_CONFIG_UCM2 across
  # several services.
  nixpkgs.overlays = [
    (_final: prev: {
      alsa-ucm-conf = prev.alsa-ucm-conf.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          mkdir -p $out/share/alsa/ucm2/conf.d/avs_max98373
          cp ${nocturne}/config/ucm2/Google-Nocturne-1.0.conf \
            $out/share/alsa/ucm2/conf.d/avs_max98373/
        '';
      });
    })
  ];

  # Touchpad/touchscreen quirks for this chassis.
  environment.etc."libinput/local-overrides.quirks".source =
    "${nocturne}/config/libinput/local-overrides.quirks";

  environment.systemPackages = with pkgs; [
    alsa-utils
  ];

  # Wall panel: never sleep, never idle off. HandlePowerKey=ignore is the
  # important one -- systemd's default is `poweroff`, so without it a stray
  # tap on a wall-mounted tablet shuts the machine down.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleSuspendKey = "ignore";
    HandlePowerKey = "ignore";
    IdleAction = "ignore";
  };
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
  };

  # ...and instead make the power button a display on/off toggle.
  services.actkbd = {
    enable = true;
    bindings = [
      {
        keys = [ 116 ]; # KEY_POWER
        events = [ "key" ];
        command = "${toggleDisplay}";
      }
    ];
  };

  # --- The panel's own user ------------------------------------------------
  # Unprivileged (deliberately not in wheel) and passwordless, so both the
  # kiosk session and GDM autologin come up unattended.
  users.users.tablet = {
    isNormalUser = true;
    description = "Wall panel session";
    group = "users";
    extraGroups = [
      "video"
      "input"
    ];
    hashedPassword = "";
  };

  # The empty password above is only ever usable at the physical console:
  # sshd has password auth off repo-wide, and this shuts the door explicitly.
  services.openssh.settings.DenyUsers = [ "tablet" ];

  # --- Kiosk session -------------------------------------------------------
  # greetd's initial_session is the autologin: it launches sway as `tablet`
  # with no prompt, and sway brings up the browser full-screen.
  services.greetd = lib.mkIf (!desktop) {
    enable = true;
    settings.initial_session = {
      command = "${lib.getExe pkgs.sway} --config ${swayConfig}";
      user = "tablet";
    };
  };

  # --- Interactive desktop -------------------------------------------------
  # Handy while working on the hardware by hand. GNOME has the most consistent
  # touch handling and picks sane HiDPI scaling on its own.
  services.desktopManager.gnome.enable = desktop;
  services.displayManager = lib.mkIf desktop {
    gdm.enable = true; # Wayland-only as of GNOME 50; no toggle to set
    autoLogin = {
      enable = true;
      user = "tablet";
    };
  };
}
