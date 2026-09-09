{ config, ... }:
let
  desktopHome = config.flake.modules.homeManager.hyprland;
in
{
  flake.modules.nixos.hyprland = { config, lib, ... }: {
    options.fleet.desktop.reviewed = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Graphical login, fingerprint/password fallback, locking/sleep, portals, audio and mobile displays have been reviewed. Not an eGPU/HDR certification.";
    };
    config = {
      fleet.bootstrap.missing =
        lib.optional (!config.fleet.desktop.reviewed)
          "Verify desktop login, fingerprint/password fallback, locking/sleep, portals, audio and mobile display; acknowledge fleet.desktop.reviewed.";
      assertions = [
        {
          assertion = !(config.services.greetd.settings ? initial_session);
          message = "The fleet desktop requires authenticated login, never greetd autologin.";
        }
        {
          assertion = config.home-manager.useGlobalPkgs && config.home-manager.useUserPackages;
          message = "The desktop must use its host's packages and NixOS-managed user profiles.";
        }
      ];
      programs.hyprland = {
        enable = true;
        withUWSM = true;
        xwayland.enable = true;
      };
      programs.uwsm.waylandCompositors.hyprland = {
        prettyName = "Hyprland";
        binPath = "/run/current-system/sw/bin/start-hyprland";
      };
      services = {
        # Noctalia replaces the text frontend, not greetd's PAM/session backend.
        displayManager.noctalia-greeter = {
          enable = true;
          settings = {
            session.default = "Hyprland (UWSM)";
            keyboard.layout = "us";
            cursor.size = 24;
            # Empty submission starts PAM fingerprint fallback; PAM still
            # rejects empty-password accounts and the final deny rule remains.
            auth = {
              allow_empty_password = true;
              request_timeout = 60;
            };
          };
        };
        pipewire = {
          enable = true;
          alsa.enable = true;
          pulse.enable = true;
        };
        gnome.gnome-keyring.enable = true;
      };
      hardware.graphics.enable = true;
      security.rtkit.enable = true;
      xdg.portal.config.hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        sharedModules = [ desktopHome ];
        backupFileExtension = null;
      };
    };
  };

  flake.modules.homeManager.hyprland =
    { lib, pkgs, ... }:
    let
      inline = lib.generators.mkLuaInline;
      toLua = lib.generators.toLua { };
      dispatch = name: args: inline "hl.dsp.${name}(${toLua args})";
      bind = key: action: {
        _args = [
          key
          action
        ];
      };
      app = command: dispatch "exec_cmd" "${lib.getExe pkgs.uwsm} app -- ${command}";
      shell = command: dispatch "exec_cmd" "${lib.getExe pkgs.noctalia} msg ${command}";
    in
    {
      fonts.fontconfig.enable = true;
      xdg.enable = true;
      wayland.windowManager.hyprland = {
        enable = true;
        package = null;
        portalPackage = null;
        systemd.enable = false; # UWSM alone owns the session lifecycle.
        configType = "lua";
        # Home Manager owns serialization. Only dispatcher expressions need the
        # upstream mkLuaInline escape hatch; no hand-written whole Lua config.
        settings = {
          monitor = [
            {
              output = "";
              mode = "preferred";
              position = "auto";
              scale = 1;
              cm = "srgb";
              bitdepth = 8;
              vrr = 0;
            }
          ];
          env = [
            {
              _args = [
                "XCURSOR_SIZE"
                "24"
              ];
            }
            {
              _args = [
                "HYPRCURSOR_SIZE"
                "24"
              ];
            }
          ];
          config = {
            general = {
              layout = "dwindle";
              gaps_in = 4;
              gaps_out = 8;
              border_size = 2;
              resize_on_border = true;
              allow_tearing = false;
              col = {
                active_border = "#89b4fa";
                inactive_border = "#45475a";
              };
            };
            decoration = {
              rounding = 8;
              active_opacity = 1.0;
              inactive_opacity = 1.0;
              blur.enabled = false;
              shadow.enabled = false;
            };
            animations.enabled = true;
            dwindle.preserve_split = true;
            input = {
              kb_layout = "us";
              touchpad = {
                natural_scroll = true;
                tap_to_click = true;
                disable_while_typing = true;
              };
            };
            misc = {
              disable_hyprland_logo = true;
              disable_splash_rendering = true;
              background_color = "#11111b";
            };
          };
          bind = [
            (bind "SUPER + Return" (app (lib.getExe pkgs.ghostty)))
            (bind "SUPER + B" (app "zen"))
            (bind "SUPER + E" (app "nautilus"))
            (bind "SUPER + Space" (shell "panel-toggle launcher"))
            (bind "SUPER + A" (shell "panel-toggle control-center"))
            (bind "SUPER + SHIFT + L" (shell "session lock"))
            (bind "SUPER + SHIFT + Escape" (shell "panel-toggle session"))
            (bind "ALT + Tab" (shell "window-switcher"))
            (bind "Print" (shell "screenshot-region"))
            (bind "SUPER + Q" (inline "hl.dsp.window.close()"))
            (bind "SUPER + V" (dispatch "window.float" { action = "toggle"; }))
            (bind "SUPER + F" (dispatch "window.fullscreen" { action = "toggle"; }))
            {
              _args = [
                "SUPER + mouse:272"
                (inline "hl.dsp.window.drag()")
                { mouse = true; }
              ];
            }
            {
              _args = [
                "SUPER + mouse:273"
                (inline "hl.dsp.window.resize()")
                { mouse = true; }
              ];
            }
          ]
          ++
            lib.concatMap
              (direction: [
                (bind "SUPER + ${direction}" (dispatch "focus" { inherit direction; }))
                (bind "SUPER + SHIFT + ${direction}" (dispatch "window.move" { inherit direction; }))
              ])
              [
                "left"
                "right"
                "up"
                "down"
              ]
          ++ lib.concatMap (
            workspace:
            let
              key = toString (lib.mod workspace 10);
            in
            [
              (bind "SUPER + ${key}" (dispatch "focus" { inherit workspace; }))
              (bind "SUPER + SHIFT + ${key}" (dispatch "window.move" { inherit workspace; }))
            ]
          ) (lib.range 1 10)
          ++
            lib.mapAttrsToList
              (key: command: {
                _args = [
                  key
                  (shell command)
                  {
                    locked = true;
                    repeating = true;
                  }
                ];
              })
              {
                XF86AudioRaiseVolume = "volume-up";
                XF86AudioLowerVolume = "volume-down";
                XF86AudioMute = "volume-mute";
                XF86AudioMicMute = "mic-mute";
                XF86MonBrightnessUp = "brightness-up";
                XF86MonBrightnessDown = "brightness-down";
              };
          gesture = {
            fingers = 3;
            direction = "horizontal";
            action = "workspace";
          };
        };
      };
    };
}
