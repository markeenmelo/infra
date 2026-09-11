{
  flake.modules.nixos.hyprland =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      services = {
        gvfs.enable = true;
        udisks2.enable = true;
        # Discovery for the approved IPP/eSCL devices. Do not publish local services.
        avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
          publish.enable = false;
        };
        printing = {
          enable = true;
          allowFrom = [ "localhost" ];
          browsed.enable = false;
          browsing = false;
          defaultShared = false;
          listenAddresses = [ "localhost:631" ];
          openFirewall = false;
        };
      };
      hardware = {
        bluetooth = {
          enable = true;
          powerOnBoot = true;
        };
        sane = {
          enable = true;
          extraBackends = [ pkgs.sane-airscan ];
        };
      };
      programs = {
        zsh.enable = true;
        kdeconnect.enable = true;
      };
      users.users = lib.optionalAttrs (config.fleet.access.admin != null) {
        ${config.fleet.access.admin} = {
          shell = pkgs.zsh;
          extraGroups = [
            "scanner"
            "lp"
          ];
        };
      };
      environment.persistence."/persist".directories = [
        {
          directory = "/var/lib/bluetooth";
          mode = "0700";
        }
        # Native CUPS stores queues/PPDs here (/etc/cups is its symlink).
        # Caches and print-job spool remain ephemeral; finish jobs before reboot.
        "/var/lib/cups"
      ];
    };

  # Endpoint recovered from the current printer configuration, not a discovered
  # scanner URI or a certificate-verification claim. Verify after authorization.
  fleet.hosts.thinkpad.module = { lib, ... }: {
    hardware.printers = {
      ensureDefaultPrinter = "Epson_ET-3850";
      ensurePrinters = [
        {
          name = "Epson_ET-3850";
          description = "Epson EcoTank ET-3850";
          deviceUri = "ipps://192.168.4.20:631/ipp/print";
          model = "everywhere";
          ppdOptions."printer-is-shared" = "false";
        }
      ];
    };
    systemd.services.ensure-printers = {
      # `-m everywhere` queries the printer even when its queue already exists.
      # Keep native provisioning explicit; ordinary boots use persisted CUPS
      # queues/PPDs without needing the home network. Never retry it on rebuild.
      wantedBy = lib.mkForce [ ];
      restartIfChanged = false;
    };
  };

  flake.modules.homeManager.hyprland = { pkgs, ... }: {
    home.packages = with pkgs; [
      nautilus
      file-roller
      papers
      loupe
      simple-scan
      pavucontrol
      networkmanagerapplet
    ];
    programs.btop.enable = true;
    services.kdeconnect = {
      enable = true;
      indicator = false; # The Noctalia tray is sufficient; one daemon.
    };
    xdg = {
      # Both packages ship global XDG autostarts. Noctalia owns the NM agent;
      # HM's session-bound unit owns KDE Connect. Mask only those entries,
      # using native desktop-file generation; leave Bitwarden/other state alone.
      autostart = {
        enable = true;
        readOnly = false;
        entries =
          map
            (
              name:
              "${
                pkgs.makeDesktopItem {
                  inherit name;
                  desktopName = "Disabled duplicate ${name} autostart";
                  exec = "${pkgs.coreutils}/bin/false";
                  noDisplay = true;
                  extraConfig.Hidden = "true";
                }
              }/share/applications/${name}.desktop"
            )
            [
              "nm-applet"
              "org.kde.kdeconnect.daemon"
            ];
      };
      mimeApps = {
        enable = true;
        defaultApplications = {
          "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
          "application/pdf" = [ "org.gnome.Papers.desktop" ];
          "application/zip" = [ "org.gnome.FileRoller.desktop" ];
          "application/x-7z-compressed" = [ "org.gnome.FileRoller.desktop" ];
          "application/x-tar" = [ "org.gnome.FileRoller.desktop" ];
          "image/jpeg" = [ "org.gnome.Loupe.desktop" ];
          "image/png" = [ "org.gnome.Loupe.desktop" ];
          "image/webp" = [ "org.gnome.Loupe.desktop" ];
        };
      };
      terminal-exec = {
        enable = true;
        settings.default = [ "com.mitchellh.ghostty.desktop" ];
      };
    };
    # Deliberately no media player, nm-applet, second polkit/notification agent,
    # automatic vault unlock or forced MIME-file ownership migration.
  };
}
