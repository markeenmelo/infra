{
  flake.modules.darwin.desktop =
    { config, ... }:
    {
      system.defaults = {
        dock = {
          autohide = true;
          autohide-time-modifier = 0.0;
          expose-animation-duration = 0.1;
          show-recents = false;
          mru-spaces = false;
          wvous-tl-corner = 1;
          wvous-tr-corner = 1;
          wvous-bl-corner = 1;
          wvous-br-corner = 1;
        };
        finder = {
          AppleShowAllExtensions = true;
          ShowPathbar = true;
          FXPreferredViewStyle = "Nlsv";
          FXEnableExtensionChangeWarning = false;
          FXDefaultSearchScope = "SCcf";
          NewWindowTarget = "Home";
        };
        NSGlobalDomain = {
          AppleInterfaceStyle = "Dark";
          AppleSpacesSwitchOnActivate = false;
          NSAutomaticWindowAnimationsEnabled = false;
          NSWindowResizeTime = 0.001;
          AppleICUForce24HourTime = true;
          AppleKeyboardUIMode = 3;
          KeyRepeat = 2;
          InitialKeyRepeat = 20;
          ApplePressAndHoldEnabled = false;
          NSAutomaticSpellingCorrectionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSAutomaticDashSubstitutionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticCapitalizationEnabled = false;
          NSDocumentSaveNewDocumentsToCloud = false;
          "com.apple.swipescrolldirection" = false;
        };
        trackpad = {
          Clicking = true;
          TrackpadRightClick = true;
          TrackpadThreeFingerDrag = true;
        };
        controlcenter.BatteryShowPercentage = true;
        screencapture = {
          location = "${config.users.users.${config.system.primaryUser}.home}/Pictures/Screenshots";
          disable-shadow = true;
          show-thumbnail = false;
        };
        screensaver = {
          askForPassword = true;
          askForPasswordDelay = 0;
        };
        loginwindow.GuestEnabled = false;
      };
      home-manager.users.${config.system.primaryUser}.home.file."Pictures/Screenshots/.keep".text = "";
    };
}
