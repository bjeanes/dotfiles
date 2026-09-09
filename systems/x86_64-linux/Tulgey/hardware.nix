# Hardware enablement specific to the Pixel Slate. The generated
# hardware-configuration.nix next to this covers filesystems and initrd
# modules; this covers the things nixos-generate-config can't know about.
{
  inputs,
  pkgs,
  ...
}:
let
  nocturne = inputs.nocturne-linux;
in
{
  # ChromeOS-era hardware wants a recent kernel: cros_ec drivers for the
  # embedded controller and its sensors, and the Intel AVS audio driver.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.graphics.enable = true;

  # Touchscreen (Wacom WCOM50C1, with a separate stylus node) and the
  # detachable's touchpad both come up under libinput.
  services.libinput.enable = true;

  # Quirks for this chassis' input devices, from nocturne-linux.
  environment.etc."libinput/local-overrides.quirks".source =
    "${nocturne}/config/libinput/local-overrides.quirks";

  # The embedded controller exposes cros-ec-accel, cros-ec-gyro and
  # cros-ec-light (plus an acpi-als), so rotation and ambient-light brightness
  # have real sensors behind them. Whether iio-sensor-proxy actually delivers
  # working auto-rotate here is untested.
  hardware.sensor.iio.enable = true;
}
