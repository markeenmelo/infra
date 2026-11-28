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
        overwriteBackup = true;
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
      boot.plymouth.enable = true;
      boot.consoleLogLevel = 3;
      boot.kernelParams = [
        "quiet"
        "udev.log_level=3"
        "systemd.show_status=auto"
      ];
      boot.kernel.sysctl = {
        "vm.swappiness" = 180;
        "vm.page-cluster" = 0;
      };
      networking.networkmanager = {
        enable = true;
        connectionConfig."ipv4.dhcp-send-hostname" = false;
      };
      systemd.user.settings.Manager.DefaultTimeoutStopSec = "10s";
      systemd.services = {
        systemd-logind.restartTriggers = [ config.environment.etc."systemd/logind.conf".source ];
        upower = {
          enableStrictShellChecks = true;
          preStart = "printf 1 > /var/lib/upower/charging-threshold-status";
        };
        "btrfs-scrub@".unitConfig.ConditionACPower = true;
        tailscale-exit-node = {
          description = "Route through the vpn-ca exit node by default";
          wantedBy = [
            "multi-user.target"
            "tailscaled-set.service"
          ];
          after = [ "tailscaled-set.service" ];
          wants = [ "tailscaled-set.service" ];
          path = [
            config.services.tailscale.package
            pkgs.jaq
          ];
          enableStrictShellChecks = true;
          restartIfChanged = false;
          script = ''
            for _ in $(seq 30); do
              if tailscale set --exit-node=vpn-ca; then
                tailscale status --json | jaq -e '.ExitNodeStatus.Online' > /dev/null && exit 0
                echo "tailscale-exit-node: the node named vpn-ca is offline; internet is down until another exit node is picked" >&2
                exit 1
              fi
              sleep 10
            done
            echo "tailscale-exit-node: vpn-ca stayed unreachable for 5 minutes; the exit node is left as it was" >&2
            exit 1
          '';
        };
      };
      services.btrfs.autoScrub.interval = "weekly";
      networking.modemmanager.enable = false;
      security.rtkit.enable = true;
      programs.zsh.enable = true;
      users.users.marcos.shell = pkgs.zsh;
      services = {
        resolved.enable = true;
        tailscale = {
          useRoutingFeatures = "client";
          extraUpFlags = [ "--reset" ];
          extraSetFlags = [
            "--accept-routes"
            "--exit-node-allow-lan-access"
          ];
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
        logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
        gvfs.enable = true;
        power-profiles-daemon.enable = true;
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
    { lib, pkgs, ... }:
    {
      imports = [ inputs.luciole.homeModules.default ];
      home.packages = lib.filter (lib.meta.availableOn pkgs.stdenv.hostPlatform) [
        pkgs.file-roller
        pkgs.loupe
        pkgs.papers
        pkgs.telegram-desktop
        pkgs.whatsapp-electron
        pkgs.spotify
        pkgs.bruno
        inputs.paseo.packages.${pkgs.stdenv.hostPlatform.system}.desktop
        pkgs.wl-clipboard
      ];
      programs = {
        luciole.enable = true;
        vesktop.enable = true;
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
