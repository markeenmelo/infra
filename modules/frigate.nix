{ config, ... }:
let
  inherit (config.fleet) domain;
  port = 8971;
  rtspPort = 8554;
  go2rtcPort = 1984;
  streams = {
    tapo = "FRIGATE_TAPO_MAIN";
    tapo_sub = "FRIGATE_TAPO_SUB";
  };
  secrets = {
    FRIGATE_TAPO_MAIN = "frigate-main";
    FRIGATE_TAPO_SUB = "frigate-sub";
  };
in
{
  flake.modules.nixos.frigate =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      gpu = "${utils.escapeSystemdPath config.fleet.renderDevice}.device";
      model = config.services.frigate.package.models.openvino.ssdlite_mobilenet_v2_coco;
      credentials = lib.mapAttrsToList (
        name: secret: "${name}:${config.sops.secrets.${secret}.path}"
      ) secrets;
    in
    {
      # the ids that own scratch/frigate, allocated by the old generation
      users.users.frigate.uid = 968;
      users.groups.frigate.gid = 964;
      sops.secrets = lib.genAttrs (lib.attrValues secrets) (_: {
        sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
        restartUnits = [
          "frigate.service"
          "go2rtc.service"
        ];
      });
      nixpkgs.overlays = [
        (_: prev: {
          # shortcut: pybind11 3.1.0 runs keep_alive before overload matching (pybind11#6183), breaking ov.Tensor(type, shape); drop once nixpkgs ships a fixed pybind11
          frigate = prev.frigate.overrideAttrs (old: {
            postPatch = old.postPatch + ''
              substituteInPlace frigate/detectors/detection_runners.py \
                --replace-fail "ov.Tensor(input_element_type, input_shape)" \
                  "ov.Tensor(np.zeros(tuple(input_shape), dtype=input_element_type.to_dtype()))" \
                --replace-fail "ov.Tensor(input_element_type, input_data.shape)" \
                  "ov.Tensor(np.zeros(input_data.shape, dtype=input_element_type.to_dtype()))"
            '';
          });
        })
      ];
      fileSystems."/var/cache/frigate" = {
        fsType = "tmpfs";
        options = [
          "size=1g"
          "mode=0750"
          "nosuid"
          "nodev"
          "noexec"
        ];
      };
      services = {
        frigate = {
          enable = true;
          hostname = "frigate.${domain}";
          vaapiDriver = "iHD";
          preCheckConfig = "export FRIGATE_TAPO_MAIN=rtsp://127.0.0.1:554/main FRIGATE_TAPO_SUB=rtsp://127.0.0.1:554/sub";
          settings = {
            auth = {
              enabled = true;
              cookie_secure = true;
            };
            logger.logs."frigate.app" = "warning";
            detectors.ov = {
              type = "openvino";
              device = "GPU";
            };
            model = {
              width = 300;
              height = 300;
              input_tensor = "nhwc";
              input_pixel_format = "bgr";
              path = "${model}/ssdlite_mobilenet_v2.xml";
              labelmap_path = "${model.labelmap}";
            };
            ffmpeg = {
              path = pkgs.jellyfin-ffmpeg;
              hwaccel_args = "preset-intel-qsv-h264";
            };
            detect = {
              enabled = true;
              fps = 3;
            };
            objects.track = [ "person" ];
            record = {
              enabled = true;
              continuous.days = 7;
              alerts.retain = {
                days = 30;
                mode = "all";
              };
              detections.retain = {
                days = 30;
                mode = "all";
              };
            };
            snapshots = {
              enabled = true;
              retain.default = 30;
            };
            go2rtc.streams = lib.mapAttrs (_: variable: "{${variable}}") streams;
            cameras.tapo = {
              zones.person_area = {
                coordinates = "0,1,0.997,0.997,0.999,0.199,0.754,0.167,0.451,0.198,0.21,0.288,0.152,0.337,0.13,0.201,0.002,0.358";
                objects = [ "person" ];
              };
              review = {
                alerts.required_zones = [ "person_area" ];
                detections.required_zones = [ "person_area" ];
              };
              snapshots.required_zones = [ "person_area" ];
              ffmpeg.inputs = [
                {
                  path = "rtsp://127.0.0.1:${toString rtspPort}/tapo";
                  input_args = "preset-rtsp-restream";
                  roles = [ "record" ];
                }
                {
                  path = "rtsp://127.0.0.1:${toString rtspPort}/tapo_sub";
                  input_args = "preset-rtsp-restream";
                  roles = [ "detect" ];
                }
              ];
              ffmpeg.output_args.record = "preset-record-generic";
              live.streams.Main = "tapo";
            };
          };
        };
        go2rtc = {
          enable = true;
          settings = {
            api.listen = "127.0.0.1:${toString go2rtcPort}";
            rtsp.listen = "127.0.0.1:${toString rtspPort}";
            webrtc.listen = "";
            srtp.listen = "";
            log.level = "fatal";
            streams = lib.mapAttrs (_: variable: "\${${variable}}") streams;
          };
        };
        nginx = {
          virtualHosts.${config.services.frigate.hostname}.listen = [
            {
              addr = "127.0.0.1";
              inherit port;
            }
          ];
          appendConfig = lib.mkForce "";
        };
      };
      fleet.web.apps.frigate.port = port;
      networking.nftables.tables.frigate = {
        family = "inet";
        content = ''
          chain output {
            type filter hook output priority -150; policy accept;
            oifname "lo" tcp dport { 1984, 5000, 5001, 5002, 8082, ${toString rtspPort} } meta skuid != { ${toString config.users.users.frigate.uid}, ${toString config.users.users.nginx.uid} } reject
          }
        '';
      };
      systemd.services = {
        frigate = {
          wants = [ gpu ];
          after = [ gpu ];
          unitConfig.RequiresMountsFor = "/var/lib/frigate";
          serviceConfig = {
            KillMode = "mixed";
            TimeoutStopSec = "30s";
            LoadCredential = credentials;
          };
        };
        go2rtc.serviceConfig.LoadCredential = credentials;
      };
    };
}
