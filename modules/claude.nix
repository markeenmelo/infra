{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (config.fleet) domain;
  inherit (config.flake.modules.homeManager) claude;
  tokens =
    owner:
    lib.genAttrs [ "github-mcp-token" "grafana-mcp-token" ] (_: {
      inherit owner;
      sopsFile = ../secrets/shared/mcp.yaml;
    });
  deniedDirs = [
    "/run/secrets"
    "/run/secrets.d"
    "/private/var/run/secrets"
    "/private/var/run/secrets.d"
    "/run/user"
  ];
  managedSettings = builtins.toJSON {
    permissions.disableBypassPermissionsMode = "disable";
    sandbox = {
      enabled = true;
      failIfUnavailable = true;
      allowUnsandboxedCommands = false;
      network.strictAllowlist = true;
      filesystem.denyRead = deniedDirs;
    };
  };
in
{
  flake.modules = {
    darwin.desktop.homebrew.casks = [ "claude" ];

    darwin.base =
      { config, pkgs, ... }:
      {
        home-manager.users.${config.system.primaryUser}.imports = [ claude ];
        sops.secrets = tokens config.system.primaryUser;
        nixpkgs.config.allowUnfreePackages = [
          "claude-code"
          "rtk"
        ];
        system.activationScripts.postActivation.text = ''
          install -d -m 0755 "/Library/Application Support/ClaudeCode"
          ln -sfn ${pkgs.writeText "claude-managed-settings.json" managedSettings} "/Library/Application Support/ClaudeCode/managed-settings.json"
        '';
      };

    nixos.desktop =
      { pkgs, ... }:
      {
        home-manager.users.marcos.imports = [ claude ];
        sops.secrets = tokens "marcos";
        nixpkgs.config.allowUnfreePackages = [
          "claude-code"
          "rtk"
        ];
        environment = {
          systemPackages = [
            pkgs.bubblewrap
            pkgs.socat
          ];
          etc."claude-code/managed-settings.json".text = managedSettings;
        };
      };

    homeManager.claude =
      {
        config,
        lib,
        osConfig,
        pkgs,
        ...
      }:
      {
        home = {
          packages = [
            pkgs.nodejs
            pkgs.rtk
          ];
          file."${config.programs.claude-code.configDir}/.ponytail-band".text = "off";
        };
        xdg.configFile = {
          "ponytail/config.json".text = builtins.toJSON {
            defaultMode = "ultra";
            hideStatus = true;
          };
          "caveman/config.json".text = builtins.toJSON { defaultMode = "ultracave"; };
        };
        programs.mcp = {
          enable = true;
          servers = {
            nixos.command = lib.getExe pkgs.mcp-nixos;
            github = {
              command = lib.getExe pkgs.github-mcp-server;
              args = [
                "stdio"
                "--read-only"
                "--toolsets=repos,pull_requests,actions"
              ];
              env.GITHUB_PERSONAL_ACCESS_TOKEN.file = osConfig.sops.secrets.github-mcp-token.path;
            };
            grafana = {
              command = lib.getExe pkgs.mcp-grafana;
              args = [ "--disable-write" ];
              env = {
                GRAFANA_URL = "https://grafana.${domain}";
                GRAFANA_SERVICE_ACCOUNT_TOKEN.file = osConfig.sops.secrets.grafana-mcp-token.path;
              };
            };
          };
        };
        programs.claude-code = {
          enable = true;
          enableMcpIntegration = true;
          lspServers.nix = {
            command = lib.getExe pkgs.nixd;
            extensionToLanguage.".nix" = "nix";
          };
          settings = {
            theme = "dark-ansi";
            attribution = {
              commit = "";
              pr = "";
            };
            env = {
              RTK_SUPPRESS_HOOK_WARNING = "1";
              CLAUDE_CODE_PLUGIN_DIRS = lib.concatStringsSep ":" [
                "${inputs.cache-tax}"
                "${inputs.ponytail}"
                "${inputs.caveman}"
              ];
            };
            hooks.PreToolUse = [
              {
                matcher = "Bash";
                hooks = [
                  {
                    type = "command";
                    command = "${lib.getExe pkgs.rtk} hook claude";
                  }
                ];
              }
            ];
            permissions = {
              defaultMode = "auto";
              blockReadsOutsideWorkingDirectories = true;
              allow = [
                "mcp__plugin_hm_nixos__nix"
                "mcp__plugin_hm_nixos__nix_versions"
              ]
              ++ map (tool: "mcp__plugin_hm_github__${tool}") [
                "get_*"
                "list_*"
                "search_*"
                "pull_request_read"
              ];
              deny = map (file: "Read(${file})") (
                [
                  "~/.claude/.credentials.json"
                  "~/.claude.json"
                  "~/.ssh/**"
                  "~/.config/sops/**"
                  "~/.config/gh/**"
                  "~/Library/Keychains/**"
                  "~/Library/Application Support/sops/**"
                  "~/Library/Application Support/Bitwarden/**"
                  "~/Library/Application Support/Zen/**"
                  "~/Library/Application Support/Claude/**"
                  "~/.bitwarden-ssh-agent.sock"
                  "~/.gnupg/**"
                  "~/.local/share/keyrings/**"
                  "~/.config/Bitwarden/**"
                  "~/.zen/**"
                  "~/.config/zen/**"
                ]
                ++ map (dir: "/${dir}/**") deniedDirs
              );
            };
          };
        };
      };
  };
}
