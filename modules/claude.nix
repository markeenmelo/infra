{ inputs, ... }:
let
  secretDirs = [
    "/run/secrets"
    "/run/secrets.d"
    "/private/var/run/secrets"
    "/private/var/run/secrets.d"
  ];
  managedSettings = builtins.toJSON {
    permissions.disableBypassPermissionsMode = "disable";
    sandbox = {
      enabled = true;
      failIfUnavailable = true;
      allowUnsandboxedCommands = false;
      network.strictAllowlist = true;
      filesystem.denyRead = secretDirs;
    };
  };
in
{
  flake.modules = {
    darwin.desktop.homebrew.casks = [ "claude" ];

    darwin.base =
      { config, pkgs, ... }:
      {
        sops.secrets.github-mcp-token = {
          sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
          owner = config.system.primaryUser;
        };
        nixpkgs.config.allowUnfreePackages = [
          "claude-code"
          "rtk"
        ];
        system.activationScripts.postActivation.text = ''
          install -d -m 0755 "/Library/Application Support/ClaudeCode"
          ln -sfn ${pkgs.writeText "claude-managed-settings.json" managedSettings} "/Library/Application Support/ClaudeCode/managed-settings.json"
        '';
      };

    homeManager.base =
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
                ]
                ++ map (dir: "/${dir}/**") secretDirs
              );
            };
          };
        };
      };
  };
}
