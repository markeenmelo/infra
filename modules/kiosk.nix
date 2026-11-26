{ config, inputs, ... }:
let
  inherit (config.flake.modules.nixos) operator-login;
in
{
  flake.modules.nixos.kiosk =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      java = pkgs.graalvmPackages.graalvm-ce;
      prism = pkgs.prismlauncher.override { jdks = [ java ]; };
      pack = pkgs.callPackage "${inputs.nix-minecraft}/pkgs/tools/fetchModrinthModpack" { } {
        pname = "fabulously-optimized";
        version = "14.1.2";
        url = "https://cdn.modrinth.com/data/1KVo5zza/versions/OuZrT7BT/Fabulously.Optimized-v14.1.2.mrpack";
        side = "client";
        packHash = "sha256-R/x2dCdlT9XjmR9EY4Eb1fXSOALg5TVwhdNAvW/OkME=";
        postInstall = "rm $out/mods/e4mc*";
      };
      memory = ''
        MinMemAlloc=4096
        MaxMemAlloc=6144
      '';
      launcher = pkgs.writeText "prismlauncher.cfg" ''
        [General]
        Language=en_US
        ApplicationTheme=system
        JavaPath=${java}/bin/java
        ${memory}
      '';
      instance = pkgs.writeText "instance.cfg" ''
        [General]
        InstanceType=OneSix
        name=Fabulously Optimized
        OverrideJavaLocation=true
        JavaPath=${java}/bin/java
        OverrideMemory=true
        ${memory}
        OverrideJavaArgs=true
        JvmArgs=-XX:+UseZGC -XX:+AlwaysPreTouch -XX:+UseTransparentHugePages -XX:+UseStringDeduplication
        OverrideNativeWorkarounds=true
        UseNativeOpenAL=true
        OverridePerformance=true
        EnableFeralGamemode=true
      '';
      components = pkgs.writeText "mmc-pack.json" (
        builtins.toJSON {
          formatVersion = 1;
          components = [
            {
              uid = "net.minecraft";
              version = "26.2";
              important = true;
            }
            {
              uid = "net.fabricmc.fabric-loader";
              version = "0.20.1";
            }
          ];
        }
      );
      session = {
        user = "ian";
        command = "${lib.getExe config.programs.gamescope.package} --fullscreen -- ${lib.getExe prism} --launch fo";
      };
    in
    {
      imports = [ operator-login ];
      users.users.ian = {
        isNormalUser = true;
        uid = 1001;
        description = "Ian";
        extraGroups = [
          "audio"
          "video"
          "input"
        ];
      };
      systemd.services.minecraft-instance = {
        description = "Lay the declared Minecraft instance into Ian's Prism Launcher";
        wantedBy = [ "greetd.service" ];
        before = [ "greetd.service" ];
        serviceConfig = {
          Type = "oneshot";
          User = "ian";
        };
        script = ''
          data=$HOME/.local/share/PrismLauncher
          game=$data/instances/fo/.minecraft
          mkdir -p "$game"
          seed() {
            [ -e "$2" ] || install -m 644 "$1" "$2"
          }
          seed ${launcher} "$data/prismlauncher.cfg"
          seed ${instance} "$data/instances/fo/instance.cfg"
          seed ${components} "$data/instances/fo/mmc-pack.json"
          [ -e "$game/config" ] || { cp -r ${pack}/config "$game/config"; chmod -R u+w "$game/config"; }
          ln -sfn ${pack}/mods "$game/mods"
          ln -sfn ${pack}/resourcepacks "$game/resourcepacks"
        '';
      };
      services.greetd = {
        enable = true;
        restart = true;
        settings = {
          initial_session = session;
          default_session = session;
        };
      };
      programs.gamescope.enable = true;
      programs.gamemode.enable = true;
      hardware = {
        graphics.enable = true;
        bluetooth.enable = true;
      };
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
      };
      powerManagement.cpuFreqGovernor = "performance";
      nix = {
        settings.max-jobs = 0;
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 14d";
        };
      };
    };
}
