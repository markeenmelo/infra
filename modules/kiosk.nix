{ config, inputs, ... }:
let
  inherit (config.flake.modules.nixos) operator-login steam;
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
      chooser = pkgs.writeText "chooser.qml" ''
        import QtQuick
        import QtQuick.Window

        Window {
          visible: true
          visibility: Window.FullScreen
          color: "#1e2326"
          Row {
            anchors.centerIn: parent
            spacing: 80
            Repeater {
              model: [
                { label: "Minecraft", icon: "${pkgs.prismlauncher-unwrapped}/share/icons/hicolor/scalable/apps/org.prismlauncher.PrismLauncher.svg", code: 10 },
                { label: "Steam", icon: "${pkgs.steam-unwrapped}/share/icons/hicolor/256x256/apps/steam.png", code: 11 },
                { label: "Plasma", icon: "${pkgs.kdePackages.breeze-icons}/share/icons/breeze/places/64/start-here-kde-plasma.svg", code: 12 }
              ]
              delegate: Column {
                spacing: 24
                Rectangle {
                  width: 320
                  height: 320
                  radius: 48
                  color: area.pressed ? "#3d484d" : "#2d353b"
                  Image {
                    anchors.centerIn: parent
                    width: 220
                    height: 220
                    sourceSize: Qt.size(220, 220)
                    fillMode: Image.PreserveAspectFit
                    source: "file://" + modelData.icon
                  }
                  MouseArea {
                    id: area
                    anchors.fill: parent
                    onClicked: Qt.exit(modelData.code)
                  }
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: modelData.label
                  color: "#d3c6aa"
                  font.pixelSize: 48
                }
              }
            }
          }
        }
      '';
      pick = pkgs.writeShellScript "kiosk-pick" ''
        export QML_IMPORT_PATH=${pkgs.qt6.qtdeclarative}/lib/qt-6/qml
        export QT_PLUGIN_PATH=${pkgs.qt6.qtbase}/lib/qt-6/plugins:${pkgs.qt6.qtwayland}/lib/qt-6/plugins
        ${pkgs.qt6.qtdeclarative}/bin/qml ${chooser}
        echo $? > "$XDG_RUNTIME_DIR/kiosk-choice"
      '';
      kioskSession = pkgs.writeShellApplication {
        name = "kiosk-session";
        runtimeInputs = [
          pkgs.cage
          config.programs.gamescope.package
          prism
          config.programs.steam.package
          (pkgs.writeShellScriptBin "steamos-session-select" "exec steam -shutdown")
        ];
        text = ''
          choice=$XDG_RUNTIME_DIR/kiosk-choice
          while true; do
            rm -f "$choice"
            cage -- ${pick} || true
            case $(cat "$choice" 2> /dev/null || true) in
              10) gamescope --fullscreen -- prismlauncher --launch fo || true ;;
              11) gamescope --steam --fullscreen -- steam -gamepadui -steamos3 || true ;;
              12) startplasma-wayland || true ;;
              *) sleep 1 ;;
            esac
          done
        '';
      };
      session = {
        user = "ian";
        command = lib.getExe kioskSession;
      };
    in
    {
      imports = [
        operator-login
        steam
      ];
      users.users.ian = {
        isNormalUser = true;
        uid = 1001;
        description = "Ian";
        extraGroups = [
          "audio"
          "video"
          "input"
          "gamemode"
        ];
      };
      systemd.services.minecraft-instance = {
        description = "Lay the declared Minecraft instance into Ian's Prism Launcher";
        wantedBy = [
          "multi-user.target"
          "greetd.service"
        ];
        before = [ "greetd.service" ];
        path = [ pkgs.crudini ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "ian";
        };
        script = ''
          data=$HOME/.local/share/PrismLauncher
          game=$data/instances/fo/.minecraft
          mkdir -p "$game"
          own() {
            touch "$2"
            crudini --ini-options=nospace --merge "$2" < "$1"
          }
          own ${launcher} "$data/prismlauncher.cfg"
          own ${instance} "$data/instances/fo/instance.cfg"
          install -m 644 ${components} "$data/instances/fo/mmc-pack.json"
          [ -e "$game/config" ] || { cp -r ${pack}/config "$game/config"; chmod -R u+w "$game/config"; }
          ln -sfnT ${pack}/mods "$game/mods"
          ln -sfnT ${pack}/resourcepacks "$game/resourcepacks"
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
      services.desktopManager.plasma6.enable = true;
      services.power-profiles-daemon.enable = false;
      environment.etc."xdg/kscreenlockerrc".text = ''
        [Daemon][$i]
        Autolock=false
        LockOnResume=false
      '';
      security.polkit.extraConfig = ''
        polkit.addRule(function (action, subject) {
          if (subject.user == "ian" && action.id.indexOf("org.freedesktop.NetworkManager.") == 0) {
            return polkit.Result.NO;
          }
        });
      '';
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
      systemd.services.bedtime = {
        description = "Power off for the night";
        serviceConfig.ExecStart = "${config.systemd.package}/bin/systemctl poweroff";
        startAt = [
          "*-*-* 13:00:00"
          "*-*-* 20:00:00"
        ];
      };
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
