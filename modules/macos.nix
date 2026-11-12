{
  flake.modules.darwin.desktop =
    { config, lib, ... }:
    {
      system.defaults = {
        CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys =
          lib.mapAttrs' (_: id: lib.nameValuePair (toString id) { enabled = false; })
            {
              nextWindow = 27; # cmd+`
              showDesktop = 36; # F11
              previousInputSource = 60; # ctrl+space
              nextInputSource = 61; # ctrl+alt+space
              spotlight = 64; # cmd+space
              finderSearchWindow = 65; # cmd+alt+space
              desktop1 = 118; # ctrl+1
              desktop2 = 119; # ctrl+2
              desktop3 = 120; # ctrl+3
              desktop4 = 121; # ctrl+4
            };
        dock = {
          autohide = true;
          autohide-delay = 0.0;
          autohide-time-modifier = 0.0;
          expose-animation-duration = 0.1;
          launchanim = false;
          magnification = false;
          minimize-to-application = true;
          show-process-indicators = true;
          showhidden = true;
          show-recents = false;
          mru-spaces = false;
          tilesize = 28;
          persistent-apps = map (app: { inherit app; }) [
            "/Applications/Zen.app"
            "/Applications/Ghostty.app"
            "/Applications/Zed.app"
            "/Applications/Spotify.app"
            "/Applications/Telegram.app"
            "/Applications/WhatsApp.app"
          ];
          persistent-others = [ ];
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
          "com.apple.sound.beep.volume" = 0.0;
          "com.apple.sound.beep.feedback" = 0;
        };
        trackpad = {
          Clicking = true;
          TrackpadRightClick = true;
          TrackpadThreeFingerDrag = true;
        };
        controlcenter.BatteryShowPercentage = true;
        WindowManager = {
          StandardHideWidgets = true;
          EnableStandardClickToShowDesktop = false;
        };
        CustomUserPreferences."com.apple.finder".ShowRecentTags = false;
        CustomUserPreferences."com.apple.systemsound"."com.apple.sound.uiaudio.enabled" = 0;
        # 4 is macOS's blue accent
        CustomUserPreferences.NSGlobalDomain.AppleAccentColor = 4;
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
      system.startup.chime = false;
      home-manager.users.${config.system.primaryUser}.home.file."Pictures/Screenshots/.keep".text = "";
    };
}
