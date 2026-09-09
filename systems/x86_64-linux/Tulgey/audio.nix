# Intel AVS: 2x MAX98373 speakers over TDM/I2S, plus DMICs.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  nocturne = inputs.nocturne-linux;

  avsFirmware = pkgs.runCommand "nocturne-avs-firmware" { } ''
    mkdir -p $out/lib/firmware/intel/avs/skl
    cp ${nocturne}/config/firmware/avs/*.bin $out/lib/firmware/intel/avs/
    cp ${nocturne}/config/firmware/avs/skl/*.bin $out/lib/firmware/intel/avs/skl/
  '';

  # No upstream profile for this board, and one is required: the speaker PCM is
  # device 1 and there is no device 0, so the non-UCM fallback finds nothing.
  # Atlas is the same machine driver and codecs, so its profile fits verbatim.
  # nocturne-linux's own ucm2 profile is a stub that cannot load.
  ucm2 = pkgs.symlinkJoin {
    name = "alsa-ucm-conf-nocturne";
    paths = [
      pkgs.alsa-ucm-conf
      (pkgs.runCommand "nocturne-ucm2" { } ''
        src=${pkgs.alsa-ucm-conf}/share/alsa/ucm2/Intel/avs/avs_max98373
        # Fail loudly on an upstream rename; the HiFi half is included by path.
        test -f "$src/Google-Atlas-1.0.conf"
        test -f "$src/Google-Atlas-1.0-HiFi.conf"

        d=$out/share/alsa/ucm2/conf.d/avs_max98373
        mkdir -p "$d"
        cp "$src/Google-Atlas-1.0.conf" "$d/Google-Nocturne-1.0.conf"
      '')
    ];
  };
  ucm2Dir = "${ucm2}/share/alsa/ucm2";

  # Without this the default sink is HDMI, i.e. an empty port.
  # 1400 stays under the 1500 above which a sink's monitor can win as source.
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
    cp ${nocturne}/config/wireplumber/53-device-names.conf "$d/"
    cp ${preferSpeakers} "$d/54-prefer-internal-speakers.conf"
  '';

in
{
  # dsp_driver=4 selects AVS; ignore_fw_version=1 is required for the
  # ChromeOS-extracted blobs.
  boot.extraModprobeConfig = builtins.readFile "${nocturne}/config/modprobe/snd-avs.conf";

  hardware.firmware = [ avsFirmware ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.configPackages = [ wirePlumberConfig ];
  };

  # systemd user services don't inherit environment.sessionVariables.
  systemd.user.services = lib.genAttrs [ "pipewire" "pipewire-pulse" "wireplumber" ] (_: {
    environment.ALSA_CONFIG_UCM2 = ucm2Dir;
  });

  environment.sessionVariables.ALSA_CONFIG_UCM2 = ucm2Dir;

  environment.systemPackages = with pkgs; [ alsa-utils ];
}
