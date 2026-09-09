# Power behaviour for a device screwed to a wall: never sleep, never idle off,
# and repurpose the power button as a display toggle.
{ pkgs, ... }:
let
  # Writes bl_power (the standard sysfs blanking control) and zeroes brightness
  # as a belt-and-braces measure, since not every driver honours bl_power.
  # Verified on this device: one backlight, /sys/class/backlight/intel_backlight,
  # max_brightness 65535, bl_power present. One state file is therefore fine.
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
  # HandlePowerKey is the important one: systemd's default is `poweroff`, so
  # without it a stray tap on a wall-mounted tablet shuts the machine down.
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
  #
  # Caveat: while panel.interactive is true, GNOME also grabs the power key, so
  # set its power-button action to "Do Nothing" or the two will both fire. With
  # the sway kiosk nothing competes.
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
}
