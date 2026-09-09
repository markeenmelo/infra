{ config, ... }:
let
  desktopHome = config.flake.modules.homeManager.hyprland;
in
{
  flake.modules.nixos.hyprland =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.fleet.desktop.reviewed = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Graphical login, PAM locking/sleep, portals, audio and mobile display behavior have been reviewed on the target. Not an eGPU/HDR certification.";
      };
      config = {
        fleet.bootstrap.missing =
          lib.optional (!config.fleet.desktop.reviewed)
            "Verify the desktop login, locking/sleep, portals, audio and mobile display; acknowledge fleet.desktop.reviewed.";

        assertions = [
          {
            assertion = !(config.services.greetd.settings ? initial_session);
            message = "The fleet desktop requires authenticated login, not greetd autologin.";
          }
          {
            assertion = config.home-manager.useGlobalPkgs && config.home-manager.useUserPackages;
            message = "The fleet desktop must use its host's packages and NixOS-managed user profiles.";
          }
        ];

        programs.hyprland = {
          enable = true;
          withUWSM = true;
          xwayland.enable = true;
        };
        programs.uwsm.waylandCompositors.hyprland = {
          prettyName = "Hyprland";
          # Preserve start-hyprland's watchdog and use the activated system binary.
          binPath = "/run/current-system/sw/bin/start-hyprland";
        };
        services = {
          greetd = {
            enable = true;
            useTextGreeter = true;
            settings.default_session.command =
              "${lib.getExe pkgs.tuigreet} --time --cmd "
              + lib.escapeShellArg "${lib.getExe config.programs.uwsm.package} start -F -- /run/current-system/sw/bin/start-hyprland";
          };
          pipewire = {
            enable = true;
            alsa.enable = true;
            pulse.enable = true;
          };
          # PAM can unlock a password-matching Secret Service keyring. No existing
          # password, keyring or Wi-Fi secret is imported by this feature.
          gnome.gnome-keyring.enable = true;
        };
        hardware.graphics.enable = true;
        security.rtkit.enable = true;
        security.pam.services.greetd.enableGnomeKeyring = true;
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
          # Keep collision checks: activation must not overwrite unmanaged dotfiles.
          backupFileExtension = null;
        };
      };
    };

  flake.modules.homeManager.hyprland = { lib, pkgs, ... }: {
    programs.foot = {
      enable = true;
      settings.main.font = "monospace:size=11";
    };
    home.packages = [ pkgs.firefox ];
    fonts.fontconfig.enable = true;
    xdg.enable = true;

    # Both locked Hyprland releases use Lua. Managing the file directly avoids
    # coupling this configuration to Home Manager's evolving Lua serializer.
    xdg.configFile."hypr/hyprland.lua".text = ''
      -- Fresh fleet desktop. No copied user dotfiles or forced NVIDIA environment.
      -- Automatic GPU discovery keeps future outputs visible; do not pin cardN.
      hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1,
                   cm = "srgb", bitdepth = 8, vrr = 0 })

      hl.env("XCURSOR_SIZE", "24")
      hl.env("HYPRCURSOR_SIZE", "24")
      hl.config({
        general = {
          layout = "dwindle", gaps_in = 4, gaps_out = 8, border_size = 2,
          resize_on_border = true, allow_tearing = false,
          col = { active_border = "#89b4fa", inactive_border = "#45475a" },
        },
        decoration = {
          rounding = 8,
          active_opacity = 1.0, inactive_opacity = 1.0,
          blur = { enabled = false },
          shadow = { enabled = false },
        },
        animations = { enabled = true },
        dwindle = { preserve_split = true },
        input = {
          kb_layout = "us",
          touchpad = { natural_scroll = true, tap_to_click = true,
                       disable_while_typing = true },
        },
        misc = { disable_hyprland_logo = true, disable_splash_rendering = true,
                 background_color = "#11111b" },
      })

      -- UWSM, not a second Home Manager/compositor session target, owns services.
      -- Noctalia is started once by its graphical-session user service.
      local function app(command)
        return hl.dsp.exec_cmd("${lib.getExe pkgs.uwsm} app -- " .. command)
      end
      local function shell(command)
        return hl.dsp.exec_cmd("${lib.getExe pkgs.noctalia} msg " .. command)
      end

      hl.bind("SUPER + Return", app("${lib.getExe pkgs.foot}"))
      hl.bind("SUPER + B", app("${lib.getExe pkgs.firefox}"))
      hl.bind("SUPER + Space", shell("panel-toggle launcher"))
      hl.bind("SUPER + A", shell("panel-toggle control-center"))
      hl.bind("SUPER + SHIFT + L", shell("session lock"))
      hl.bind("SUPER + SHIFT + Escape", shell("panel-toggle session"))
      hl.bind("ALT + Tab", shell("window-switcher"))
      hl.bind("Print", shell("screenshot-region"))
      hl.bind("SUPER + Q", hl.dsp.window.close())
      hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))
      hl.bind("SUPER + F", hl.dsp.window.fullscreen({ action = "toggle" }))

      for _, direction in ipairs({ "left", "right", "up", "down" }) do
        hl.bind("SUPER + " .. direction, hl.dsp.focus({ direction = direction }))
        hl.bind("SUPER + SHIFT + " .. direction,
                hl.dsp.window.move({ direction = direction }))
      end
      for workspace = 1, 10 do
        local key = workspace % 10
        hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = workspace }))
        hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
      end
      hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
      hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

      for key, command in pairs({
        XF86AudioRaiseVolume = "volume-up", XF86AudioLowerVolume = "volume-down",
        XF86AudioMute = "volume-mute", XF86AudioMicMute = "mic-mute",
        XF86MonBrightnessUp = "brightness-up", XF86MonBrightnessDown = "brightness-down",
      }) do
        hl.bind(key, shell(command), { locked = true, repeating = true })
      end
    '';
  };
}
