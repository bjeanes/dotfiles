# Pixel Slate enablement that nixos-generate-config can't infer.
{
  inputs,
  pkgs,
  ...
}:
let
  nocturne = inputs.nocturne-linux;
in
{
  # cros_ec and Intel AVS want a recent kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # PSR2 is suspected of freezing the panel; keep PSR1.
  boot.kernelParams = [ "i915.enable_psr=1" ];

  hardware.graphics.enable = true;

  services.libinput.enable = true;

  environment.etc."libinput/local-overrides.quirks".source =
    "${nocturne}/config/libinput/local-overrides.quirks";

  # cros-ec accel/gyro/light exist; auto-rotate itself is untested.
  hardware.sensor.iio.enable = true;
}
