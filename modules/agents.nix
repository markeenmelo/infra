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
  githubAppId = "5897261";
  githubToken = "github-token";
  tokenVariables = {
    claude-token = "CLAUDE_CODE_OAUTH_TOKEN";
    paseo-password = "PASEO_PASSWORD";
    grafana-token = "GRAFANA_SERVICE_ACCOUNT_TOKEN";
    zai-api-key = "ZAI_API_KEY";
    kimi-api-key = "KIMI_API_KEY";
    minimax-api-key = "MINIMAX_API_KEY";
  };

  guest =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      gh = pkgs.writeShellScriptBin "gh" ''
        GH_TOKEN=$(cat ${guestSecrets}/${githubToken}) exec ${lib.getExe pkgs.gh} "$@"
      '';
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
        mem = 12288;
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
          AllowUsers = [ "marcos" ];
        };
        hostKeys = [
          {
            path = "/var/lib/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };

      users.users.marcos = {
        isNormalUser = true;
        uid = agentUid;
        openssh.authorizedKeys.keys = [ (import ./_operator-key.nix) ];
      };
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.marcos = {
          imports = [ agent-tools ];
          home.stateVersion = config.system.stateVersion;
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
        config.credential."https://github.com".helper = "!${lib.getExe gh} auth git-credential";
      };
      environment.systemPackages = [
        gh
        pkgs.ripgrep
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.cursor-agent
      ];
      services.paseo = {
        enable = true;
        user = "marcos";
        group = "users";
        relay.enable = false;
        listenAddress = "0.0.0.0";
        port = paseoPort;
        hostnames = [ "agents" ];
        settings = {
          version = 1;
          daemon = {
            cors.allowedOrigins = [ ];
            relay.enabled = false;
            mcp.injectIntoAgents = true;
            usage.enabled = true;
            browserTools.enabled = false;
            enableTerminalAgentHooks = true;
            terminalProfiles = [
              {
                id = "claude";
                name = "Claude Code";
                command = "claude";
                args = [ "{{{prompt}}}" ];
                icon = "claude";
              }
              {
                id = "pi";
                name = "Pi";
                command = "pi";
                args = [ "{{{prompt}}}" ];
                icon = "pi";
              }
            ];
          };
          agents = {
            resumeOnStartup = false;
            providers =
              lib.genAttrs [ "muse" "antigravity" "copilot" "opencode" "codex" ] (_: {
                enabled = false;
              })
              // {
                cursor = {
                  extends = "acp";
                  label = "Cursor";
                  description = "Cursor's coding agent";
                  command = [
                    "cursor-agent"
                    "acp"
                  ];
                };
              };
          };
        };
      };
      # shortcut: /home/agent stays a symlink so the absolute paths in Paseo's and the Nix profile's state still resolve; drop it with this unit once nothing under /home/marcos names /home/agent
      systemd.services.home-move = {
        description = "Move the operator's home from /home/agent to /home/marcos, finishing an interrupted move";
        wantedBy = [ "sysinit.target" ];
        requiredBy = [
          "home-manager-marcos.service"
          "paseo.service"
        ];
        before = [
          "systemd-tmpfiles-setup.service"
          "sysinit.target"
          "sshd.service"
          "paseo.service"
          "home-manager-marcos.service"
        ];
        after = [ "local-fs.target" ];
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/home";
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        enableStrictShellChecks = true;
        script = ''
          projects=/home/marcos/.claude/projects
          if [ -d /home/agent ] && [ ! -L /home/agent ]; then
            if [ -e /home/marcos ]; then
              rmdir /home/marcos
            fi
            mv /home/agent /home/marcos
          fi
          if [ ! -e /home/agent ] && [ ! -L /home/agent ]; then
            ln -s marcos /home/agent
          fi
          for project in "$projects/-home-agent" "$projects"/-home-agent-*; do
            [ -e "$project" ] || continue
            target="$projects/-home-marcos''${project#"$projects"/-home-agent}"
            if [ -e "$target" ]; then echo "home-move: $target exists, leaving $project" >&2; else mv -- "$project" "$target"; fi
          done
          if [ -f /home/marcos/.claude.json ]; then
            sed -i -E 's#/home/agent([/"])#/home/marcos\1#g' /home/marcos/.claude.json
          fi
        '';
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

      users.users.marcos.uid = agentUid;

      microvm.vms.agents = {
        config = guest;
        restartIfChanged = false;
      };
      systemd.tmpfiles.settings.agents."/nix/var/nix/gcroots/agents-booted"."L+".argument =
        "${stateDir}/agents/booted";

      sops.secrets = lib.mkMerge [
        {
          agents-tailscale-auth-key.key = "agents/tailscale-auth-key";
          agents-github-app-key.key = "agents/github-api-key";
        }
        (lib.listToAttrs (
          map (
            name:
            lib.nameValuePair "agents-${name}" {
              key = "agents/${name}";
              restartUnits = [ "agents-restart.service" ];
            }
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
        agents-github-token = {
          description = "Mint the agent guest's one-hour GitHub App installation token";
          wantedBy = [ "microvm-virtiofsd@agents.service" ];
          after = [
            "microvm-virtiofsd@agents.service"
            "network-online.target"
          ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            UMask = "0077";
            Restart = "on-failure";
            RestartSec = "1min";
            LoadCredential = "key:${config.sops.secrets.agents-github-app-key.path}";
          };
          enableStrictShellChecks = true;
          script = ''
            ${lib.getExe pkgs.gh-token} generate --key "$CREDENTIALS_DIRECTORY/key" --app-id ${githubAppId} --token-only > ${hostSecrets}/.${githubToken}
            chown ${toString agentUid} ${hostSecrets}/.${githubToken}
            mv ${hostSecrets}/.${githubToken} ${hostSecrets}/${githubToken}
          '';
        };
      };
      systemd.timers.agents-github-token = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnActiveSec = "1s";
          OnCalendar = "*:00/30";
        };
      };
    };
}
