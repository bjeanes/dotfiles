# Intel AVS audio for the Pixel Slate: 2x Maxim MAX98373 speakers over TDM/I2S
# plus DMICs.
#
# The AVS driver binds on its own -- cards enumerate as AVS DMIC, AVS I2S
# MAX98373 and AVS HDMI -- but that's just the machine driver registering ahead
# of DSP firmware load. On a stock install /lib/firmware/intel/avs/ doesn't
# exist at all and no module options are set, so nothing can actually play.
#
# NOTE: the speakers may still not work until the *firmware* carries the
# coreboot NHLT 32-bit-render-format fix, which a stock MrChromebox ROM does
# not. See nocturne.md, "Audio", for the full picture.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  nocturne = inputs.nocturne-linux;

  # AVS DSP firmware and topology blobs, extracted from ChromeOS. Paths mirror
  # what the driver looks for: /lib/firmware/intel/avs/{,skl/}*.bin
  # (The repo's avs-topology-xml submodule is only the source for regenerating
  # these; the built .bin files are committed, so it isn't needed.)
  avsFirmware = pkgs.runCommand "nocturne-avs-firmware" { } ''
    mkdir -p $out/lib/firmware/intel/avs/skl
    cp ${nocturne}/config/firmware/avs/*.bin $out/lib/firmware/intel/avs/
    cp ${nocturne}/config/firmware/avs/skl/*.bin $out/lib/firmware/intel/avs/skl/
  '';

  # The UCM2 profile isn't upstream. ALSA checks $ALSA_CONFIG_UCM2 before its
  # compiled-in path, so point that at a merged tree rather than overriding
  # alsa-ucm-conf -- alsa-lib sits deep enough in the graph that overriding it
  # rebuilds chromium, ffmpeg, wayland and much else. This costs two symlink
  # farms and compiles nothing.
  ucm2 = pkgs.symlinkJoin {
    name = "alsa-ucm-conf-nocturne";
    paths = [
      pkgs.alsa-ucm-conf
      (pkgs.runCommand "nocturne-ucm2" { } ''
        mkdir -p $out/share/alsa/ucm2/conf.d/avs_max98373
        cp ${nocturne}/config/ucm2/Google-Nocturne-1.0.conf \
          $out/share/alsa/ucm2/conf.d/avs_max98373/
      '')
    ];
  };
  ucm2Dir = "${ucm2}/share/alsa/ucm2";

  # Headroom bump and volume limit for these speakers.
  # (53-device-names.conf exists upstream but setup.sh doesn't install it.)
  wirePlumberConfig = pkgs.runCommand "nocturne-wireplumber-config" { } ''
    d=$out/share/wireplumber/wireplumber.conf.d
    mkdir -p "$d"
    cp ${nocturne}/config/wireplumber/51-increase-headroom.conf "$d/"
    cp ${nocturne}/config/wireplumber/52-volume-limit.conf "$d/"
  '';
in
{
  # dsp_driver=4 forces AVS; ignore_fw_version=1 is required because the
  # ChromeOS-extracted blobs don't match the version the driver expects, and
  # without it firmware load fails outright.
  boot.extraModprobeConfig = builtins.readFile "${nocturne}/config/modprobe/snd-avs.conf";

  hardware.firmware = [ avsFirmware ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.configPackages = [ wirePlumberConfig ];
  };

  # Has to be set on the units: systemd *user* services don't inherit
  # environment.sessionVariables.
  systemd.user.services = lib.genAttrs [ "pipewire" "pipewire-pulse" "wireplumber" ] (_: {
    environment.ALSA_CONFIG_UCM2 = ucm2Dir;
  });

  # ...and in the session too, for interactive poking (aplay -L, alsaucm).
  environment.sessionVariables.ALSA_CONFIG_UCM2 = ucm2Dir;

  environment.systemPackages = with pkgs; [
    alsa-utils # aplay/amixer/alsaucm, for diagnosing the above
  ];
}
