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
      home-manager.users.${config.system.primaryUser} =
        { lib, pkgs, ... }:
        {
          home.file."Pictures/Screenshots/.keep".text = "";
          home.activation.finderSidebar = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            sidebar=${pkgs.mysides}/bin/mysides
            for name in Recents AirDrop Applications Desktop Documents Movies Music Pictures; do
              "$sidebar" remove "$name" > /dev/null 2>&1 || true
            done
            have=$("$sidebar" list 2> /dev/null || true)
            mkdir -p "$HOME/projects" "$HOME/notes"
            for entry in "marcos file://$HOME/" "projects file://$HOME/projects/" "notes file://$HOME/notes/" "Downloads file://$HOME/Downloads/"; do
              set -- $entry
              printf '%s\n' "$have" | grep -Fqx "$1 -> $2" || run "$sidebar" add "$1" "$2"
            done
          '';
        };
    };
}
