{
  flake.modules.darwin.desktop =
    { config, ... }:
    {
      system.defaults = {
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
            "/Applications/Ghostty.app"
            "/Applications/Zen.app"
            "/Applications/Zed.app"
            "/Applications/Telegram.app"
            "/Applications/WhatsApp.app"
            "/Applications/Spotify.app"
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
      homebrew.brews = [ "mysides" ];
      home-manager.users.${config.system.primaryUser} =
        { lib, ... }:
        {
          home.file."Pictures/Screenshots/.keep".text = "";
          home.activation.finderSidebar = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            sidebar=${config.homebrew.prefix}/bin/mysides
            [ -x "$sidebar" ] || exit 0
            for name in Recents AirDrop Applications Desktop Documents Movies Music Pictures; do
              "$sidebar" remove "$name" > /dev/null 2>&1 || true
            done
            have=$("$sidebar" list 2> /dev/null || true)
            mkdir -p "$HOME/projects" "$HOME/notes"
            for entry in "marcos file://$HOME/" "projects file://$HOME/projects/" "notes file://$HOME/notes/" "Downloads file://$HOME/Downloads/"; do
              set -- $entry
              case $have in *"$2"*) ;; *) run "$sidebar" add "$1" "$2" ;; esac
            done
          '';
        };
    };
}
