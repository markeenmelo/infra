{ inputs, ... }:
let
  box = import ./_guest.nix inputs (import ./_hermes.nix);
  hostSecrets = "/run/hermes-secrets";
  guestSecrets = "/host-secrets";
  secrets = [
    "env"
    "auth"
  ];

  guest =
    { config, pkgs, ... }:
    let
      cfg = config.services.hermes-agent;
    in
    {
      imports = [
        box.guest
        inputs.hermes-agent.nixosModules.default
      ];

      microvm = {
        vcpu = 2;
        mem = 4096;
        volumes = [
          {
            image = "var.img";
            label = "var";
            mountPoint = "/var/lib";
            size = 16 * 1024;
          }
        ];
        shares = [
          {
            proto = "virtiofs";
            tag = "secrets";
            source = hostSecrets;
            mountPoint = guestSecrets;
            readOnly = true;
          }
        ];
      };
      fileSystems = {
        "/var/lib".neededForBoot = true;
        ${guestSecrets} = {
          neededForBoot = true;
          options = [
            "nosuid"
            "nodev"
            "noexec"
          ];
        };
      };

      services.hermes-agent = {
        enable = true;
        package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.messaging;
        settings = {
          model = {
            provider = "openai-codex";
            default = "gpt-6-luna";
          };
          unauthorized_dm_behavior = "ignore";
          auth.adopt_external_logins = false;
          updates.check = false;
        };
        environmentFiles = [ "${guestSecrets}/env" ];
      };

      systemd.services.hermes-auth = {
        description = "Give Hermes the ChatGPT sign-in bastion holds when it changed";
        requiredBy = [ "hermes-agent.service" ];
        before = [ "hermes-agent.service" ];
        unitConfig.RequiresMountsFor = [
          guestSecrets
          cfg.stateDir
        ];
        enableStrictShellChecks = true;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          UMask = "0077";
        };
        script = ''
          seen=${cfg.stateDir}/.auth-seeded
          new=$(sha256sum < ${guestSecrets}/auth)
          if [ "$new" != "$(cat "$seen" 2> /dev/null)" ]; then
            install -o ${cfg.user} -g ${cfg.group} -m 0600 ${guestSecrets}/auth ${cfg.stateDir}/.hermes/auth.json
            printf '%s\n' "$new" > "$seen"
          fi
        '';
      };
    };
in
{
  flake.modules.nixos.hermes =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      secret = name: config.sops.secrets."hermes-${name}".path;
    in
    {
      imports = [ box.host ];

      microvm.vms.hermes.config = {
        imports = [ guest ];
        time.timeZone = config.time.timeZone;
      };

      sops.secrets = lib.listToAttrs (
        map (
          name:
          lib.nameValuePair "hermes-${name}" {
            key = "hermes/${name}";
            restartUnits = [ "microvm-virtiofsd@hermes.service" ];
          }
        ) secrets
      );

      systemd.services."microvm-virtiofsd@hermes".serviceConfig.ExecStartPre = map (
        name: "${lib.getExe' pkgs.coreutils "install"} -D -m 0400 ${secret name} ${hostSecrets}/${name}"
      ) secrets;
    };
}
