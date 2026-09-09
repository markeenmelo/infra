{
  # Pi coding agent and its pinned extension set. Only the manifest, lock file
  # and the Herdr-provided session extension are vendored here; provider
  # credentials, session history and project trust stay mutable in ~/.pi.
  flake.modules.nixos.hyprland =
    { lib, ... }:
    {
      # Pi's pinned bridge/provider extensions shell out to these two unfree
      # CLIs. This is an explicit two-name allowance, never a blanket unfree
      # policy: nothing else on the fleet becomes installable by it.
      nixpkgs.config.allowUnfreePredicate =
        package:
        builtins.elem (lib.getName package) [
          "claude-code"
          "cursor-cli"
        ];
    };

  flake.modules.homeManager.hyprland =
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

      # node_modules built from the committed package.json/package-lock.json.
      # npmDepsHash covers that exact lock file; refresh both together.
      piExtensions = pkgs.buildNpmPackage {
        pname = "infra-pi-extensions";
        version = "1.0.0";
        src = ./assets/pi-extensions;
        npmDepsHash = "sha256-uZZv7Q2+v9BCeH25U8Q8phHgS84iH+RueRwYHmh0URc=";
        npmFlags = [ "--legacy-peer-deps" ];
        dontNpmBuild = true;

        installPhase = ''
          runHook preInstall

          # pi-claude-bridge 0.7.0 issue #59: keep AskClaude children from
          # discovering Claude-native skills or CLAUDE.md outside Pi's context.
          substituteInPlace node_modules/pi-claude-bridge/src/index.ts \
            --replace-fail \
              'settings: claudeCodeSettings(providerSettings),' \
              $'settings: { ...claudeCodeSettings(providerSettings), claudeMdExcludes: CLAUDE_MD_EXCLUDES },\n\t\t\tskills: [],'

          mkdir -p "$out/share/pi-extensions/pi-review"
          cp package.json "$out/share/pi-extensions/package.json"
          cp -R node_modules "$out/share/pi-extensions/node_modules"
          cp -R ${piReview}/. "$out/share/pi-extensions/pi-review/"
          printf '%s\n' ${lib.escapeShellArg piReviewRevision} \
            > "$out/share/pi-extensions/pi-review/REVISION"

          runHook postInstall
        '';
      };
    in
    {
      home = {
        # The pinned cursor provider extension resolves its CLI through this.
        sessionVariables.CURSOR_AGENT_PATH = lib.getExe pkgs.cursor-cli;

        file = {
          # Herdr ships this extension to report Pi session state to its panes.
          # Vendored verbatim; Herdr rewrites it when its integration updates.
          ".pi/agent/extensions/herdr-agent-state.ts".source = ./assets/pi/herdr-agent-state.ts;

          ".pi/agent/claude-bridge.json".source = jsonFormat.generate "pi-claude-bridge.json" {
            askClaude = {
              enabled = true;
              allowFullMode = true;
              defaultMode = "read";
              defaultIsolated = false;
              appendSkills = true;
            };
            provider = {
              plan = "pro";
              longContextExtraUsage = false;
              strictMcpConfig = true;
              autoMemoryEnabled = false;
              pathToClaudeCodeExecutable = lib.getExe pkgs.claude-code;
            };
          };

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
              imageQuality = "auto";
              usageStatus = true;
              usagePollInterval = 5;
            };
          };
        };
      };

      xdg.configFile = {
        "rpiv-ask-user-question/config.json".source = jsonFormat.generate "rpiv-ask-user-question.json" {
          collapseKey = "ctrl+]";
        };
        "rpiv-todo/config.json".source = jsonFormat.generate "rpiv-todo.json" {
          maxWidgetLines = 12;
          collapseKey = "ctrl+shift+t";
        };
      };

      programs.pi-coding-agent = {
        enable = true;
        extraPackages = [
          # Providers invoked by the pinned bridge/provider extensions.
          pkgs.claude-code
          pkgs.cursor-cli
          pkgs.gh
          pkgs.git
          pkgs.nodejs
        ];
        settings = {
          # Track the packaged release so a read-only settings file does not
          # replay the same changelog on every start.
          lastChangelogVersion = pkgs.pi-coding-agent.version;
          theme = "dark";
          defaultProvider = "openai-codex";
          defaultModel = "gpt-5.6-sol";
          defaultThinkingLevel = "xhigh";
          # Never trust a checkout implicitly; the agent must ask per project.
          defaultProjectTrust = "ask";
          packages = [ "${piExtensions}/share/pi-extensions" ];
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
