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

  # There is no UCM2 profile for this board upstream, and ALSA needs one: the
  # speaker PCM is card device *1*, and card 1 has no device 0 at all, so
  # WirePlumber's non-UCM fallback probes hw:1,0 and finds nothing.
  #
  # We deliberately do NOT use nocturne-linux's config/ucm2 profile. It is a
  # stub that cannot work:
  #   * its `SectionUseCase."HiFi" { File "HiFi.conf" }` include dangles --
  #     no HiFi.conf exists in that repo or in alsa-ucm-conf, so the profile
  #     fails to load entirely;
  #   * it carries no BootSequence, so nothing initialises the two MAX98373s
  #     (DAI select muxes, output voltage, digital volume), and nothing ever
  #     flips 'Left/Right Spk Switch' on. Silent even if the include resolved.
  #
  # Instead we reuse upstream's Google-Atlas-1.0 profile under this board's
  # card longname. Atlas is the same machine driver (avs_max98373) with the
  # same two MAX98373s, so the control names -- which come from the codec and
  # machine drivers, not the board -- are identical, and its
  # `PlaybackPCM "hw:${CardId},1"` already matches what this card exposes.
  #
  # ALSA checks $ALSA_CONFIG_UCM2 before its compiled-in path, so we point
  # that at a merged tree rather than overriding alsa-ucm-conf: alsa-lib sits
  # deep enough in the graph that overriding it rebuilds chromium, ffmpeg,
  # wayland and much else. This costs two symlink farms and compiles nothing.
  ucm2 = pkgs.symlinkJoin {
    name = "alsa-ucm-conf-nocturne";
    paths = [
      pkgs.alsa-ucm-conf
      (pkgs.runCommand "nocturne-ucm2" { } ''
        src=${pkgs.alsa-ucm-conf}/share/alsa/ucm2/Intel/avs/avs_max98373

        # The copied profile includes its HiFi half by an absolute path
        # (absolute meaning "from the ucm2 root", which the symlinkJoin below
        # makes whole). Assert both halves exist so an upstream rename fails
        # the build loudly, rather than reintroducing the dangling include
        # that this replaces.
        test -f "$src/Google-Atlas-1.0.conf"
        test -f "$src/Google-Atlas-1.0-HiFi.conf"

        d=$out/share/alsa/ucm2/conf.d/avs_max98373
        mkdir -p "$d"
        cp "$src/Google-Atlas-1.0.conf" "$d/Google-Nocturne-1.0.conf"
      '')
    ];
  };
  ucm2Dir = "${ucm2}/share/alsa/ucm2";

  # Ours. Without it the default sink lands on the HDMI node
  # (alsa_output.platform-avs_hdaudio...stereo-fallback), because WirePlumber
  # gives ALSA sinks a priority.session of 600-1000 and nothing here makes the
  # speakers preferred. On a wall panel with an empty HDMI port that means the
  # dashboard plays into nothing. 1400 puts the speakers clearly ahead while
  # staying under the documented 1500 ceiling -- above that a sink's *monitor*
  # can get selected as the default source instead.
  preferSpeakers = pkgs.writeText "54-prefer-internal-speakers.conf" ''
    monitor.alsa.rules = [
      {
        matches = [
          {
            node.name = "~alsa_output.platform-avs_max98373.*"
          }
        ]
        actions = {
          update-props = {
            priority.session = 1400
          }
        }
      }
    ]
  '';

  wirePlumberConfig = pkgs.runCommand "nocturne-wireplumber-config" { } ''
    d=$out/share/wireplumber/wireplumber.conf.d
    mkdir -p "$d"
    cp ${nocturne}/config/wireplumber/51-increase-headroom.conf "$d/"
    cp ${nocturne}/config/wireplumber/52-volume-limit.conf "$d/"
    # 53 ships in nocturne-linux but setup.sh never installs it; cosmetic
    # (device.description strings) but harmless.
    cp ${nocturne}/config/wireplumber/53-device-names.conf "$d/"
    cp ${preferSpeakers} "$d/54-prefer-internal-speakers.conf"
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
