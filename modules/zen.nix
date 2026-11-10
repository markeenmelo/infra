{ inputs, lib, ... }:
let
  locked = lib.mapAttrs (
    _: Value: {
      inherit Value;
      Status = "locked";
    }
  );
  policies = {
    ExtensionSettings = {
      "*" = {
        installation_mode = "allowed";
        install_sources = [ "https://addons.mozilla.org/*" ];
      };
      "uBlock0@raymondhill.net" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        private_browsing = true;
      };
      "7esoorv3@alefvanoon.anonaddy.me" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/libredirect/latest.xpi";
        private_browsing = true;
      };
      "sponsorBlocker@ajay.app" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
      };
      "addon@simplelogin" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/simplelogin/latest.xpi";
      };
    };
    AutofillAddressEnabled = false;
    AutofillCreditCardEnabled = false;
    DisableFeedbackCommands = true;
    DisableFirefoxAccounts = true;
    DontCheckDefaultBrowser = true;
    EnableTrackingProtection = {
      Value = true;
      Locked = true;
      Category = "strict";
      BaselineExceptions = true;
      ConvenienceExceptions = false;
    };
    FirefoxHome = {
      Search = true;
      TopSites = false;
      SponsoredTopSites = false;
      Highlights = false;
      Stories = false;
      SponsoredStories = false;
      Locked = true;
    };
    FirefoxSuggest = {
      WebSuggestions = false;
      SponsoredSuggestions = false;
      ImproveSuggest = false;
      Locked = true;
    };
    GenerativeAI = {
      Enabled = false;
      Locked = true;
    };
    HttpsOnlyMode = "enabled";
    NetworkPrediction = false;
    NoDefaultBookmarks = true;
    OfferToSaveLogins = false;
    OverrideFirstRunPage = "";
    OverridePostUpdatePage = "";
    PasswordManagerEnabled = false;
    SearchEngines = {
      Add = [
        {
          Name = "Startpage";
          URLTemplate = "https://www.startpage.com/sp/search?query={searchTerms}";
          Method = "GET";
        }
      ];
      Default = "Startpage";
    };
    Preferences = locked {
      "browser.urlbar.speculativeConnect.enabled" = false;
      "media.videocontrols.picture-in-picture.enable-when-switching-tabs.enabled" = true;
      "network.prefetch-next" = false;
    };
    UserMessaging = {
      ExtensionRecommendations = false;
      FeatureRecommendations = false;
      UrlbarInterventions = false;
      SkipOnboarding = true;
      MoreFromMozilla = false;
      FirefoxLabs = false;
      Locked = true;
    };
  };
in
{
  flake.modules.darwin.desktop.system.defaults.CustomUserPreferences."app.zen-browser.zen" = lib.mkMerge [
    policies
    { EnterprisePoliciesEnabled = true; }
  ];

  flake.modules.homeManager.desktop = {
    imports = [ inputs.zen-browser.homeModules.beta ];
    programs.zen-browser = {
      enable = true;
      inherit policies;
      profiles.default = { };
    };
    xdg.mimeApps = {
      enable = true;
      defaultApplications = lib.genAttrs [
        "text/html"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ] (_: "zen-beta.desktop");
    };
  };
}
