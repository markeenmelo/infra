{ config, inputs, ... }:
let
  inherit (config.flake.modules.nixos) nixflix;
  box = import ./_guest.nix inputs (import ./_downloads.nix);
  stateOf = [
    "sonarr"
    "radarr"
    "prowlarr"
    "qbittorrent"
    "sabnzbd"
  ];

  guest = {
    imports = [ box.guest ];
    microvm = {
      vcpu = 4;
      mem = 8192;
      volumes = [
        {
          image = "var.img";
          label = "var";
          mountPoint = "/var/lib";
          size = 16 * 1024;
        }
      ];
    };
    fileSystems."/var/lib".neededForBoot = true;
  };
in
{
  flake.modules.nixos.downloads =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      media = dirOf config.nixflix.mediaDir;
      shared = [ media ] ++ map (name: "${config.nixflix.stateDir}/${name}") stateOf;
      hostOptions = mount: lib.remove "nofail" config.fileSystems.${mount}.options;
    in
    {
      imports = [
        box.host
        nixflix
      ];

      microvm.vms.downloads.config = {
        imports = [ guest ];
        microvm.shares = map (path: {
          proto = "virtiofs";
          tag = baseNameOf path;
          source = path;
          mountPoint = path;
        }) shared;
        fileSystems = lib.genAttrs shared (path: {
          options = hostOptions (if path == media then media else config.nixflix.stateDir);
        });
      };

      systemd.services."microvm-virtiofsd@downloads" = {
        unitConfig.RequiresMountsFor = shared;
        serviceConfig.ExecStartPre = [
          "${lib.getExe' pkgs.coreutils "mkdir"} -p ${lib.concatStringsSep " " shared}"
        ];
      };
    };
}
