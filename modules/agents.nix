{
  config,
  inputs,
  lib,
  ...
}:
let
  paseoPort = config.fleet.paseoPort;
  bastion = config.fleet.hosts.bastion.tailnetAddress;
  grafana = "grafana.${config.fleet.domain}";
  inherit (config.flake.modules.nixos) claude-agent git;
  inherit (config.flake.modules.homeManager) agent-tools;
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
    paseo-password = "PASEO_PASSWORD";
    grafana-token = "GRAFANA_SERVICE_ACCOUNT_TOKEN";
  };

  guest =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      forTokens =
        line:
        lib.concatStrings (
          lib.mapAttrsToList (file: variable: ''
            if [ -r ${guestSecrets}/${file} ]; then
              ${line variable "$(cat ${guestSecrets}/${file})"}
            fi
          '') tokenVariables
        );
    in
    {
      imports = [
        box.guest
        inputs.home-manager.nixosModules.home-manager
        inputs.paseo.nixosModules.paseo
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

      networking.firewall.enable = true;
      networking.hosts.${bastion} = [ grafana ];
      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts =
        config.services.openssh.ports
        ++ [ paseoPort ];

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
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.agent = {
          imports = [ agent-tools ];
          home.stateVersion = config.system.stateVersion;
          programs.mcp.servers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN.file = "${guestSecrets}/github-token";
          programs.mcp.servers.grafana.env.GRAFANA_SERVICE_ACCOUNT_TOKEN.file =
            "${guestSecrets}/grafana-token";
        };
      };

      nix = {
        channel.enable = false;
        settings.experimental-features = [
          "nix-command"
          "flakes"
        ];
      };
      environment.extraInit = forTokens (variable: value: ''export ${variable}="${value}"'');
      programs.git = {
        enable = true;
        config.credential."https://github.com".helper = "!${lib.getExe pkgs.gh} auth git-credential";
      };
      environment.systemPackages = [
        pkgs.gh
        pkgs.ripgrep
        pkgs.cursor-cli
      ];
      services.paseo = {
        enable = true;
        package = pkgs.paseo;
        user = "agent";
        group = "users";
        relay.enable = false;
        listenAddress = "0.0.0.0";
        port = paseoPort;
        hostnames = [ "agents" ];
      };
      systemd.services.paseo = {
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        unitConfig.RequiresMountsFor = [
          "/home"
          guestSecrets
        ];
        serviceConfig = {
          RuntimeDirectory = "paseo";
          EnvironmentFile = "-/run/paseo/tokens.env";
          ExecStartPre = lib.getExe (
            pkgs.writeShellApplication {
              name = "paseo-tokens";
              text = ''
                umask 077
                password=$(cat ${guestSecrets}/paseo-password) || password=
                case $password in
                  "" | *"'"*)
                    echo "paseo-tokens: the Paseo password is missing, empty or holds a single quote; refusing to serve the tailnet without it" >&2
                    exit 1
                    ;;
                esac
                {
                  ${forTokens (variable: value: ''printf "%s='%s'\n" ${variable} "${value}"'')}
                } > "$RUNTIME_DIRECTORY/tokens.env"
              '';
            }
          );
        };
      };
    };
in
{
  options.fleet.paseoPort = lib.mkOption {
    type = lib.types.port;
    description = "Port on the agents guest where the Paseo daemon takes clients: it binds every interface and the guest's firewall admits the port on the tailnet interface alone; the `tofu` app hands it to `opentofu/tailscale` as `fleet_paseo_port`.";
  };
  config.fleet.paseoPort = 6767;

  config.flake.modules.nixos.agents =
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
        "cursor-cli"
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
