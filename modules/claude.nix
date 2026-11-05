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
        nixpkgs.config.allowUnfreePackages = [ "claude-code" ];
        system.activationScripts.postActivation.text = ''
          install -d -m 0755 "/Library/Application Support/ClaudeCode"
          install -m 0644 ${pkgs.writeText "claude-managed-settings.json" managedSettings} "/Library/Application Support/ClaudeCode/managed-settings.json"
        '';
      };

    homeManager.base =
      { lib, pkgs, ... }:
      {
        programs.claude-code = {
          enable = true;
          plugins.cache-tax = inputs.cache-tax;
          lspServers.nix = {
            command = lib.getExe pkgs.nixd;
            extensionToLanguage.".nix" = "nix";
          };
          outputStyles.concise = ''
            ---
            name: Concise
            description: Short answers without preamble or recap
            keep-coding-instructions: true
            ---

            Use the fewest words that keep the answer correct and complete. Skip preamble,
            restated questions and closing summaries. Prefer code, commands and paths over prose.
          '';
          settings = {
            theme = "dark-ansi";
            outputStyle = "Concise";
            attribution = {
              commit = "";
              pr = "";
            };
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
