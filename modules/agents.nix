{ config, inputs, ... }:
let
  inherit (config.flake.modules.nixos) claude-agent git;
  box = import ./_guest.nix inputs {
    name = "agents";
    inherit
      tap
      hostAddress
      guestAddress
      mac
      ;
  };
  tap = "vm-agents";
  hostAddress = "10.201.0.1";
  guestAddress = "10.201.0.2";
  mac = "02:00:00:00:00:01";
  hostSecrets = "/run/agents-secrets";
  guestSecrets = "/run/host-secrets";
  storeImage = "store.img";
  agentUid = 1000;
  tokenVariables = {
    claude-token = "CLAUDE_CODE_OAUTH_TOKEN";
    github-token = "GH_TOKEN";
  };

  guest =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      zedServer = pkgs.zed-editor.remoteServerExecutableName;
    in
    {
      imports = [
        box.guest
        claude-agent
        git
      ];
      microvm = {
        vcpu = 4;
        mem = 8192;
        shares = [
          {
            proto = "virtiofs";
            tag = "secrets";
            source = hostSecrets;
            mountPoint = guestSecrets;
            readOnly = true;
          }
        ];
        writableStoreOverlay = "/nix/.rw-store";
        volumes = [
          {
            image = storeImage;
            label = "store";
            mountPoint = config.microvm.writableStoreOverlay;
            size = 32 * 1024;
          }
          {
            image = "state.img";
            label = "state";
            mountPoint = "/var/lib";
            size = 1024;
          }
          {
            image = "home.img";
            label = "home";
            mountPoint = "/home";
            size = 16 * 1024;
          }
        ];
      };
      fileSystems = lib.mkMerge [
        (lib.genAttrs [ "/var/lib" "/home" ] (_: {
          neededForBoot = true;
        }))
        {
          ${guestSecrets}.options = [
            "nosuid"
            "nodev"
            "noexec"
          ];
        }
      ];
      services.journald.settings.Journal.ForwardToConsole = lib.mkForce false;

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts =
        config.services.openssh.ports;

      services.tailscale = {
        enable = true;
        openFirewall = true;
        authKeyFile = "${guestSecrets}/tailscale-auth-key";
        disableTaildrop = true;
        extraUpFlags = [
          "--reset"
          "--accept-dns=false"
        ];
      };
      systemd.services.tailscaled-autoconnect.unitConfig.RequiresMountsFor = guestSecrets;

      services.openssh = {
        enable = true;
        openFirewall = false;
        authorizedKeysInHomedir = false;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          AllowUsers = [ "agent" ];
        };
        hostKeys = [
          {
            path = "/var/lib/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };

      users.users.agent = {
        isNormalUser = true;
        uid = agentUid;
        openssh.authorizedKeys.keys = [ (import ./_operator-key.nix) ];
      };

      nix = {
        channel.enable = false;
        settings.experimental-features = [
          "nix-command"
          "flakes"
        ];
      };
      environment.extraInit = lib.concatStrings (
        lib.mapAttrsToList (file: variable: ''
          if [ -r ${guestSecrets}/${file} ]; then
            export ${variable}="$(cat ${guestSecrets}/${file})"
          fi
        '') tokenVariables
      );
      programs.git = {
        enable = true;
        config.credential."https://github.com".helper = "!${lib.getExe pkgs.gh} auth git-credential";
      };
      environment.systemPackages = [
        pkgs.gh
        pkgs.tmux
        pkgs.ripgrep
      ];
      systemd.tmpfiles.rules = [
        "d /home/agent/.zed_server 0755 agent users -"
        "L+ /home/agent/.zed_server/${zedServer} - - - - ${lib.getExe' pkgs.zed-editor.remote_server zedServer}"
      ];
    };
in
{
  flake.modules.homeManager.base.programs.zed-editor.userSettings.ssh_connections = [
    {
      host = "agents";
      username = "agent";
      projects = [ ];
    }
  ];

  flake.modules.nixos.agents =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.microvm) stateDir;
      install = lib.getExe' pkgs.coreutils "install";
      tokens = lib.attrNames tokenVariables;
      secret = name: config.sops.secrets."agents-${name}".path;
      scope = lib.concatStringsSep " " (
        map (builtins.hashFile "sha256") [
          ./agents.nix
          ./_guest.nix
          ./_operator-key.nix
        ]
      );
    in
    {
      imports = [ box.host ];

      nixpkgs.config.allowUnfreePackages = [
        "claude-code"
        "rtk"
      ];
      microvm.vms.agents = {
        config = guest;
        restartIfChanged = false;
      };
      systemd.tmpfiles.settings.agents."/nix/var/nix/gcroots/agents-booted"."L+".argument =
        "${stateDir}/agents/booted";

      sops.secrets = lib.mkMerge [
        { agents-tailscale-auth-key.key = "agents/tailscale-auth-key"; }
        (lib.listToAttrs (
          map (
            name:
            lib.nameValuePair "agents-${name}" (
              lib.mkMerge [
                {
                  key = lib.mkDefault "agents/${name}";
                  restartUnits = [ "agents-restart.service" ];
                }
                (lib.mkIf (name == "claude-token") {
                  key = name;
                  sopsFile = ../secrets/shared/claude.yaml;
                })
              ]
            )
          ) tokens
        ))
      ];

      systemd.services = {
        agents-restart = {
          description = "Restart the agent MicroVM when its definition or a token changes";
          wantedBy = [ "multi-user.target" ];
          restartTriggers = [ scope ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            UMask = "0077";
          };
          enableStrictShellChecks = true;
          script = ''
            want="${scope} $(cat ${lib.concatMapStringsSep " " secret tokens} | sha256sum)"
            seen=/run/agents-restart
            if [ -e "$seen" ] && [ "$(cat "$seen")" != "$want" ]; then
              systemctl try-restart --no-block microvm@agents.service
            fi
            printf '%s\n' "$want" > "$seen"
          '';
        };
        "microvm-virtiofsd@agents".serviceConfig.ExecStartPre = [
          "${install} -m 0400 ${secret "tailscale-auth-key"} ${hostSecrets}/tailscale-auth-key"
        ]
        ++ map (
          name: "${install} -o ${toString agentUid} -m 0400 ${secret name} ${hostSecrets}/${name}"
        ) tokens;
        "microvm@agents".serviceConfig.ExecStartPre = "${lib.getExe' pkgs.coreutils "rm"} -f ${storeImage}";
      };
    };
}
