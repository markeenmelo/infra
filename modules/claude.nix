{ inputs, ... }:
let
  managedSettings = builtins.toJSON {
    permissions.disableBypassPermissionsMode = "disable";
    sandbox = {
      enabled = true;
      failIfUnavailable = true;
      allowUnsandboxedCommands = false;
      network.strictAllowlist = true;
    };
  };
in
{
  flake.modules = {
    darwin.desktop.homebrew.casks = [ "claude" ];

    darwin.base =
      { pkgs, ... }:
      {
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
        programs.claude-code = {
          enable = true;
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
              deny = map (file: "Read(${file})") [
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
              ];
            };
          };
        };
      };
  };
}
