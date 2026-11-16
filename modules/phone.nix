let
  previewDevice = 10;
  cameraDevice = 11;
  kdeConnect = [
    {
      from = 1714;
      to = 1764;
    }
  ];
in
{
  flake.modules.nixos.desktop =
    { config, ... }:
    {
      boot = {
        extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
        kernelModules = [ "v4l2loopback" ];
        extraModprobeConfig = ''
          options v4l2loopback video_nr=${toString previewDevice},${toString cameraDevice} card_label=Preview,Phone exclusive_caps=0,1
        '';
      };
      networking.firewall.interfaces.${config.services.tailscale.interfaceName} = {
        allowedTCPPortRanges = kdeConnect;
        allowedUDPPortRanges = kdeConnect;
      };
    };

  flake.modules.homeManager.desktop =
    { pkgs, ... }:
    {
      services.kdeconnect.enable = true;
      programs.noctalia.settings = {
        plugins.enabled = [ "demencia89/androidconnect" ];
        widget.phone.type = "demencia89/androidconnect:bar";
        plugin_settings."demencia89/androidconnect" = {
          video_device = "/dev/video${toString previewDevice}";
          hide_when_disconnected = true;
          icon_color = "on_surface";
        };
      };
      home.packages = [
        pkgs.android-tools
        pkgs.scrcpy
        pkgs.python3
        pkgs.ffmpeg
        pkgs.psmisc
        (pkgs.writeShellApplication {
          name = "phone-camera";
          runtimeInputs = [ pkgs.scrcpy ];
          text = ''
            exec scrcpy --video-source=camera --camera-facing=back --camera-size=1920x1080 \
              --no-audio --no-video-playback --v4l2-sink=/dev/video${toString cameraDevice} "$@"
          '';
        })
      ];
    };
}
