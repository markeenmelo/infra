let
  # ThinkPad's desktop/HM agent policy. Servers have no agent capability.
  # Keep its existing settings and package sources unchanged.
  policyFor = { lib, pkgs }: {
    sessionVariables = {
      CURSOR_AGENT_PATH = lib.getExe pkgs.cursor-cli;
      RTK_TELEMETRY_DISABLED = "1";
    };
    extraPackages = with pkgs; [
      cursor-cli
      gh
      git
      nodejs
      rtk
    ];
    settings = {
      lastChangelogVersion = pkgs.pi-coding-agent.version;
      theme = "dark";
      defaultProvider = "openai-codex";
      defaultModel = "gpt-6-astra";
      defaultThinkingLevel = "high";
      hideThinkingBlock = true;
      # Native project-trust policy for the desktop's selected Pi.
      defaultProjectTrust = "ask";
      packages = [
        "npm:@99percentpeople/pi-codex-api@0.4.0"
        "npm:@akepka/pi-cursor-cli-provider@0.10.1"
        "npm:@ayulab/pi-rewind@0.4.6"
        "npm:@juicesharp/rpiv-ask-user-question@2.9.0"
        "npm:pi-tool-repair@0.2.5"
        "${pkgs.fetchFromGitHub {
          owner = "earendil-works";
          repo = "pi-review";
          rev = "f1de050504936046c0f85b21fec0e0a93ef394eb";
          hash = "sha256-bvdJjLudTd9YQF8ip30jIvi6MY3MAcw5GXVONx1DLuQ=";
        }}"
        # Preserve the already-reviewed independent hook pin for ThinkPad.
        "${
          pkgs.fetchFromGitHub {
            owner = "rtk-ai";
            repo = "rtk";
            tag = "v0.47.0";
            hash = "sha256-qYVkFLS6G4Tf1NmD9B3kJkyb47XREoVE65EqBtbzzjs=";
          }
        }/hooks/pi/rtk.ts"
        "${./agents/assets/empty-args-retry.ts}"
      ];
      ayu = {
        rewind.restoreOnTree = "ask";
        checkpoint = {
          restoreOnResume = false;
          restoreOnFork = false;
          restoreOnClone = false;
        };
      };
    };
    piFiles = {
      ".pi/agent/99extensions.json" = (pkgs.formats.json { }).generate "pi-99extensions.json" {
        codex-api = {
          fastMode = false;
          responseVerbosity = "auto";
          searchEnabled = true;
          imageEnabled = true;
          askEnabled = true;
          allowOtherProviders = true;
          searchMode = "auto";
          searchContextSize = "medium";
          imageModel = "gpt-image-2";
          imageQuality = "auto";
          usageStatus = true;
          usagePollInterval = 5;
        };
      };
      ".pi/agent/extensions/pi-tool-repair.json" =
        (pkgs.formats.json { }).generate "pi-tool-repair.json"
          {
            grammarRepair = {
              mode = "recover";
              requireKnownTool = true;
              grammars = [ "glm" ];
              leakModels = [ "glm" ];
            };
          };
    };
    xdgFiles = {
      "rtk/config.toml" = (pkgs.formats.toml { }).generate "rtk-config.toml" {
        telemetry = {
          enabled = false;
          consent_given = false;
        };
        tracking = {
          enabled = true;
          history_days = 90;
        };
        tee = {
          enabled = false;
          mode = "never";
          max_files = 20;
          max_file_size = 1048576;
        };
        # Never put credentials in arguments; preserve infrastructure output.
        hooks.exclude_commands = [
          "git"
          "nix"
          "nixos-rebuild"
          "just"
          "deploy"
          "disko"
          "tofu"
          "terraform"
          "ssh"
          "sops"
          "age"
        ];
      };
      "rpiv-ask-user-question/config.json" =
        (pkgs.formats.json { }).generate "rpiv-ask-user-question.json"
          {
            collapseKey = "ctrl+]";
          };
    };
  };
  cursorPolicy = { lib, ... }: {
    # Sole unfree allowance: the CLI required by the selected Cursor extension.
    nixpkgs.config.allowUnfreePredicate = package: lib.getName package == "cursor-cli";
  };
in
{
  flake.modules = {
    nixos.desktop = cursorPolicy;

    homeManager.desktop =
      { lib, pkgs, ... }:
      let
        policy = policyFor { inherit lib pkgs; };
      in
      {
        home = {
          inherit (policy) sessionVariables;
          packages = [ pkgs.rtk ];
          file = lib.mapAttrs (_: source: { inherit source; }) policy.piFiles;
        };
        xdg.configFile = lib.mapAttrs (_: source: { inherit source; }) policy.xdgFiles;
        programs.pi-coding-agent = {
          enable = true;
          inherit (policy) settings extraPackages;
        };
      };

  };
}
