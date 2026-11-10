{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.nixos.desktop =
    { config, pkgs, ... }:
    {
      imports = [ inputs.home-manager.nixosModules.home-manager ];
      home-manager = {
        backupFileExtension = "backup";
        useGlobalPkgs = true;
        useUserPackages = true;
        users.marcos = {
          imports = [
            homeManager.base
            homeManager.desktop
          ];
          home.stateVersion = config.system.stateVersion;
        };
      };
      nixpkgs.config.allowUnfreePackages = [ "spotify" ];
      hardware = {
        firmware = [ pkgs.linux-firmware ];
        bluetooth.enable = true;
      };
      zramSwap.enable = true;
      boot.kernel.sysctl = {
        "vm.swappiness" = 180;
        "vm.page-cluster" = 0;
      };
      networking.networkmanager = {
        enable = true;
        connectionConfig."ipv4.dhcp-send-hostname" = false;
      };
      networking.modemmanager.enable = false;
      security.rtkit.enable = true;
      programs.zsh.enable = true;
      users.users.marcos.shell = pkgs.zsh;
      services = {
        resolved.enable = true;
        tailscale = {
          useRoutingFeatures = "client";
          extraSetFlags = [ "--accept-routes" ];
        };
        pipewire = {
          enable = true;
          alsa.enable = true;
          pulse.enable = true;
        };
        upower = {
          enable = true;
          criticalPowerAction = "PowerOff";
        };
        power-profiles-daemon.enable = true;
        gvfs.enable = true;
        speechd.enable = false;
      };
      xdg.sounds.enable = false;
      programs.nh.flake = "${config.users.users.marcos.home}/projects/infra";
      preservation.preserveAt."/persist".directories = [
        {
          directory = "/etc/NetworkManager/system-connections";
          mode = "0700";
        }
        "/var/lib/NetworkManager"
        "/var/lib/bluetooth"
        "/var/lib/upower"
        "/var/lib/power-profiles-daemon"
        "/var/lib/systemd/backlight"
        "/var/lib/systemd/rfkill"
      ];
    };

  flake.modules.homeManager.desktop =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.nautilus
        pkgs.file-roller
        pkgs.loupe
        pkgs.papers
        pkgs.telegram-desktop
        pkgs.whatsapp-electron
        pkgs.spotify
        pkgs.vesktop
        pkgs.bruno
      ];
      programs = {
        ghostty.package = pkgs.ghostty;
        zed-editor.package = pkgs.zed-editor;
      };
      xdg = {
        enable = true;
        userDirs = {
          enable = true;
          createDirectories = true;
        };
      };
    };
}
