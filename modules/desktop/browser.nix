{ inputs, ... }: {
  flake.modules.homeManager.hyprland =
    { pkgs, ... }:
    let
      oled = builtins.fromJSON (builtins.readFile ./assets/oled-graphite.json);

      bitwardenXpi = pkgs.fetchurl {
        name = "bitwarden-2026.8.0.xpi";
        url = "https://addons.mozilla.org/firefox/downloads/file/4970633/bitwarden_password_manager-2026.8.0.xpi";
        hash = "sha256-mJ7jPxkymvH8FV3Ou3+QpRenJZzqS/vdZgkj0lp9Rlo=";
      };

      ublockOriginXpi = pkgs.fetchurl {
        name = "ublock-origin-1.74.0.xpi";
        url = "https://addons.mozilla.org/firefox/downloads/file/4981431/ublock_origin-1.74.0.xpi";
        hash = "sha256-F1dW10RoybpFhj9/wzPTvmcPgtWwZjFOkVgU3VR9FlI=";
      };

      youtubeEnhancerXpi = pkgs.fetchurl {
        name = "youtube-enhancer-1.35.0.xpi";
        url = "https://addons.mozilla.org/firefox/downloads/file/5008750/youtube_enhancer_vc-1.35.0.xpi";
        hash = "sha256-lDFZDCYVqES5UGBg8lcl+dNH2Tv9dWNqsa+m6NBZiiw=";
      };

      sponsorBlockXpi = pkgs.fetchurl {
        name = "sponsorblock-6.1.7.xpi";
        url = "https://addons.mozilla.org/firefox/downloads/file/4897574/sponsorblock-6.1.7.xpi";
        hash = "sha256-DVDhYyxvFe4VpUPmcOHFcpdGBaXAJiKRbgjgJoA9+D8=";
      };

      protonVpnXpi = pkgs.fetchurl {
        name = "proton-vpn-1.3.6.xpi";
        url = "https://addons.mozilla.org/firefox/downloads/file/4951998/proton_vpn_firefox_extension-1.3.6.xpi";
        hash = "sha256-VSKB7idK7s4PgwUvL8baO1JgIbZznD3ssDkKm178N6M=";
      };

      simpleLoginXpi = pkgs.fetchurl {
        name = "simplelogin-3.0.7.xpi";
        url = "https://addons.mozilla.org/firefox/downloads/file/4458602/simplelogin-3.0.7.xpi";
        hash = "sha256-jpHQt+K8dnRoGN2MxTPqUlucPP1DP7pS2kdmqD9Xne0=";
      };

      policies = {
        AutofillAddressEnabled = false;
        AutofillCreditCardEnabled = false;
        DisableAppUpdate = true;
        DisableFeedbackCommands = true;
        DisableFirefoxAccounts = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DontCheckDefaultBrowser = true;

        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Category = "strict";
          BaselineExceptions = true;
          ConvenienceExceptions = false;
        };

        # Firefox 152+ ignores updates_disabled for force_installed extensions.
        # normal_installed keeps exact XPI pins but lets the user disable an extension.
        ExtensionSettings = {
          "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
            installation_mode = "normal_installed";
            install_url = "file://${bitwardenXpi}";
            updates_disabled = true;
            default_area = "navbar";
            private_browsing = true;
          };

          "uBlock0@raymondhill.net" = {
            installation_mode = "normal_installed";
            install_url = "file://${ublockOriginXpi}";
            updates_disabled = true;
            default_area = "navbar";
            private_browsing = true;
          };

          "{c49b13b1-5dee-4345-925e-0c793377e3fa}" = {
            installation_mode = "normal_installed";
            install_url = "file://${youtubeEnhancerXpi}";
            updates_disabled = true;
            default_area = "menupanel";
            private_browsing = false;
          };

          "sponsorBlocker@ajay.app" = {
            installation_mode = "normal_installed";
            install_url = "file://${sponsorBlockXpi}";
            updates_disabled = true;
            default_area = "navbar";
            private_browsing = false;
          };

          "vpn@proton.ch" = {
            installation_mode = "normal_installed";
            install_url = "file://${protonVpnXpi}";
            updates_disabled = true;
            default_area = "navbar";
            private_browsing = true;
          };

          "addon@simplelogin" = {
            installation_mode = "normal_installed";
            install_url = "file://${simpleLoginXpi}";
            updates_disabled = true;
            default_area = "navbar";
            private_browsing = false;
          };
        };

        "3rdparty".Extensions = {
          "{446900e4-71c2-419f-a6a7-df9c091e268b}".environment.base = "https://vault.marcosmelo.dev";

          "uBlock0@raymondhill.net".userSettings = [
            [
              "advancedUserEnabled"
              "false"
            ]
            [
              "autoUpdate"
              "true"
            ]
            [
              "cloudStorageEnabled"
              "false"
            ]
            [
              "cnameUncloakEnabled"
              "true"
            ]
            [
              "collapseBlocked"
              "true"
            ]
            [
              "contextMenuEnabled"
              "true"
            ]
            [
              "prefetchingDisabled"
              "true"
            ]
            [
              "showIconBadge"
              "true"
            ]
            [
              "userFiltersTrusted"
              "false"
            ]
          ];
        };

        FirefoxHome = {
          Search = true;
          TopSites = false;
          SponsoredTopSites = false;
          Highlights = false;
          Pocket = false;
          Stories = false;
          SponsoredPocket = false;
          SponsoredStories = false;
          Snippets = false;
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
          Chatbot = false;
          LinkPreviews = false;
          TabGroups = false;
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

        SearchSuggestEnabled = false;

        Preferences = {
          "browser.send_pings" = {
            Value = false;
            Status = "locked";
          };
          "browser.urlbar.speculativeConnect.enabled" = {
            Value = false;
            Status = "locked";
          };
          "network.dns.disablePrefetch" = {
            Value = true;
            Status = "locked";
          };
          "network.prefetch-next" = {
            Value = false;
            Status = "locked";
          };
          "privacy.globalprivacycontrol.enabled" = {
            Value = true;
            Status = "locked";
          };
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

      # Upstream's flake package output imports pkgs again, even with follows.
      # Use this normal flake input's recipe with the consuming home's own pkgs.
      zenBrowserUnwrapped =
        (import inputs.zen-browser.outPath { inherit pkgs; }).zen-browser-unwrapped.overrideAttrs
          (previousAttrs: {
            # Nixpkgs' Firefox wrapper renamed these passthru flags under RFC 169.
            # Preserve the pinned Zen flake's declared media and GSSAPI support.
            passthru = previousAttrs.passthru // {
              withFFmpeg = previousAttrs.passthru.ffmpegSupport;
              withGSSAPI = previousAttrs.passthru.gssSupport;
            };
          });

      zenBrowser = pkgs.wrapFirefox zenBrowserUnwrapped {
        pname = "zen-browser";
        extraPolicies = policies;
        extraPrefs = ''
          lockPref("zen.welcome-screen.seen", true);
          lockPref("zen.theme.accent-color", "${oled.colors.accent}");
          lockPref("zen.theme.gradient", false);
          lockPref("zen.theme.gradient.show-custom-colors", false);
          lockPref("zen.view.compact.show-sidebar-and-toolbar-on-hover", false);
          lockPref("zen.view.grey-out-inactive-windows", false);
          lockPref("zen.widget.linux.transparency", false);
          lockPref("browser.tabs.allow_transparent_browser", false);
          lockPref("zen.view.window.scheme", 0);
          lockPref("layout.css.prefers-color-scheme.content-override", 0);
          lockPref("ui.systemUsesDarkTheme", 1);
        '';
      };
    in
    {
      home.packages = [ zenBrowser ];
      home.sessionVariables.BROWSER = "zen";
      xdg.mimeApps.defaultApplications = builtins.listToAttrs (
        map
          (name: {
            inherit name;
            value = [ "zen.desktop" ];
          })
          [
            "text/html"
            "application/xhtml+xml"
            "x-scheme-handler/http"
            "x-scheme-handler/https"
          ]
      );

      # These extensions only support UI-driven JSON import in these releases.
      xdg.configFile = {
        "sponsorblock/settings-v6.1.7.json".source = ./assets/browser/sponsorblock-settings-v6.1.7.json;
        "youtube-enhancer/settings-v1.34.2.json".source =
          ./assets/browser/youtube-enhancer-settings-v1.34.2.json;
      };
    };
}
