{
  # Pi coding agent. The extension set is declared directly in Pi's managed
  # settings: pinned `npm:` specs (Pi installs them under mutable
  # ~/.pi/agent/npm on first start) plus Nix-store local entries for the
  # hash-pinned pi-review package and the official RTK hook. Credentials,
  # sessions, installed packages and project trust stay mutable in ~/.pi.
  flake.modules.nixos.desktop =
    { lib, ... }:
    {
      # Pi's pinned Cursor provider extension shells out to this unfree CLI.
      # This is an explicit one-name allowance, never a blanket unfree policy:
      # nothing else on the fleet becomes installable by it.
      nixpkgs.config.allowUnfreePredicate = package: lib.getName package == "cursor-cli";
    };

  flake.modules.homeManager.desktop =
    { lib, pkgs, ... }:
    let
      jsonFormat = pkgs.formats.json { };

      # Pinned by the existing configuration; not a floating checkout.
      piReviewRevision = "f1de050504936046c0f85b21fec0e0a93ef394eb";
      piReview = pkgs.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi-review";
        rev = piReviewRevision;
        hash = "sha256-bvdJjLudTd9YQF8ip30jIvi6MY3MAcw5GXVONx1DLuQ=";
      };

      # Official hook delegating to the pinned Nixpkgs rtk binary; loaded as a
      # single-file extension straight from its source output.
      rtkHook = "${pkgs.rtk.src}/hooks/pi/rtk.ts";
    in
    {
      home = {
        # The pinned cursor provider extension resolves its CLI through this.
        sessionVariables = {
          CURSOR_AGENT_PATH = lib.getExe pkgs.cursor-cli;
          RTK_TELEMETRY_DISABLED = "1";
        };
        packages = [ pkgs.rtk ];

        file = {
          ".pi/agent/99extensions.json".source = jsonFormat.generate "pi-99extensions.json" {
            codex-api = {
              fastMode = false;
              responseVerbosity = "auto";
              searchEnabled = true;
              imageEnabled = true;
              askEnabled = true;
              allowOtherProviders = true;
              searchMode = "auto";
              searchContextSize = "medium";
              # pi-codex-api 0.4 defaults to Images 2.5 Flare. Preserve the
              # previously reviewed backend unless it is changed deliberately.
              imageModel = "gpt-image-2";
              imageQuality = "auto";
              usageStatus = true;
              usagePollInterval = 5;
            };
          };
          # pi-tool-repair's opt-in grammar recovery, scoped to GLM model ids
          # only: the default schema-directed argument repairs (which cover the
          # malformed `edit` calls seen from z.ai GLM models) need no config.
          ".pi/agent/extensions/pi-tool-repair.json".source = jsonFormat.generate "pi-tool-repair.json" {
            grammarRepair = {
              mode = "recover";
              requireKnownTool = true;
              grammars = [ "glm" ];
              leakModels = [ "glm" ];
            };
          };
        };
      };

      xdg.configFile = {
        "rtk/config.toml".source = (pkgs.formats.toml { }).generate "rtk-config.toml" {
          telemetry = {
            enabled = false;
            consent_given = false;
          };
          # Operator chose stock local usage statistics; never pass secrets as args.
          # 0.47 ignores enabled/history_days overrides: retain its actual defaults.
          tracking = {
            enabled = true;
            history_days = 90;
          };
          # RTK 0.47 requires the whole tee table even when disabled.
          tee = {
            enabled = false;
            mode = "never";
            max_files = 20;
            max_file_size = 1048576;
          };
          # Keep infrastructure/check/credential output unfiltered.
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
        "rpiv-ask-user-question/config.json".source = jsonFormat.generate "rpiv-ask-user-question.json" {
          collapseKey = "ctrl+]";
        };
      };

      programs.pi-coding-agent = {
        enable = true;
        extraPackages = [
          # Provider CLI invoked by the pinned cursor provider extension, plus
          # the node/npm runtime Pi itself uses to install `npm:` packages.
          pkgs.cursor-cli
          pkgs.gh
          pkgs.git
          pkgs.nodejs
          pkgs.rtk
        ];
        settings = {
          # Track the packaged release so a read-only settings file does not
          # replay the same changelog on every start.
          lastChangelogVersion = pkgs.pi-coding-agent.version;
          theme = "dark";
          defaultProvider = "openai-codex";
          defaultModel = "gpt-6-astra";
          defaultThinkingLevel = "high";
          hideThinkingBlock = true;
          # Never trust a checkout implicitly; the agent must ask per project.
          defaultProjectTrust = "ask";
          # Versioned npm specs are pinned and skipped by `pi update`; Pi
          # installs them into mutable ~/.pi/agent/npm on first start. The two
          # local entries are immutable Nix store paths.
          packages = [
            "npm:@99percentpeople/pi-codex-api@0.4.0"
            "npm:@akepka/pi-cursor-cli-provider@0.10.1"
            "npm:@ayulab/pi-rewind@0.4.6"
            "npm:@juicesharp/rpiv-ask-user-question@2.9.0"
            # Validate-then-repair of malformed tool-call arguments (stringified
            # `edits` arrays, field aliases, null optionals); GLM-covered.
            "npm:pi-tool-repair@0.2.5"
            "${piReview}"
            rtkHook
          ];
          ayu = {
            # Restoring a worktree is destructive to uncommitted work: ask, and
            # never restore automatically on resume/fork/clone.
            rewind.restoreOnTree = "ask";
            checkpoint = {
              restoreOnResume = false;
              restoreOnFork = false;
              restoreOnClone = false;
            };
          };
        };
      };
    };
}
