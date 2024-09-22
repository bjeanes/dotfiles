{ ... }:
{
  imports = [
    ./finder.nix
    ./clock.nix
  ];

  options = { };

  config = {
    security.pam.enableSudoTouchIdAuth = true;

    system.keyboard.enableKeyMapping = true;
    system.keyboard.remapCapsLockToControl = true;

    # https://archive.is/KBa2w
    system.activationScripts.postUserActivation.text = ''
      # Following line should allow us to avoid a logout/login cycle
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

    system.startup.chime = false;

    system.defaults = {
      # Disable guest logins
      loginwindow.GuestEnabled = false;

      # Disable quarantine for downloaded files
      LaunchServices.LSQuarantine = false;

      # Disable swiping for backwards/forwards
      NSGlobalDomain.AppleEnableSwipeNavigateWithScrolls = false;
      NSGlobalDomain.AppleEnableMouseSwipeNavigateWithScrolls = false;

      # Switch light/dark style of OS automatically based on time
      NSGlobalDomain.AppleInterfaceStyleSwitchesAutomatically = true;

      NSGlobalDomain.AppleMetricUnits = 1;

      # Disable press-and-hold keyboard for alt characters; this messes with key repeat and I am already used to Option+key for special characters
      NSGlobalDomain.ApplePressAndHoldEnabled = false;

      NSGlobalDomain.InitialKeyRepeat = 15;
      NSGlobalDomain.KeyRepeat = 5;

      # Disable certain text substitutions
      NSGlobalDomain.NSAutomaticQuoteSubstitutionEnabled = false; # smart quotes
      NSGlobalDomain.NSAutomaticPeriodSubstitutionEnabled = false; # period after double-space
      NSGlobalDomain.NSAutomaticCapitalizationEnabled = false;
      NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;
      NSGlobalDomain.NSAutomaticDashSubstitutionEnabled = true;

      # Jump to the spot that’s clicked on the scroll bar
      NSGlobalDomain.AppleScrollerPagingBehavior = true;
    };
  };
}
