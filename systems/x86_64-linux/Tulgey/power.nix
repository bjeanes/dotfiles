# Screwed to a wall: never sleep; power button toggles the display.
{ pkgs, ... }:
let
  # bl_power plus brightness=0, since not every driver honours bl_power.
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
  # Default HandlePowerKey is poweroff, which a stray tap would trigger.
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

  # GNOME also grabs the power key when panel.interactive is true.
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
