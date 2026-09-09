# Screwed to a wall: never sleep. The power key is bound in the sway config
# (session.nix), where the session env `wlopm` needs already exists.
{ ... }:
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
}
