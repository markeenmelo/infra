let
  policyFor = { lib, pkgs }: {
    sessionVariables = {
      CURSOR_AGENT_PATH = lib.getExe pkgs.cursor-cli;
    };
    extraPackages = with pkgs; [
      cursor-cli
      gh
      git
      nodejs
    ];
    settings = {
      lastChangelogVersion = pkgs.pi-coding-agent.version;
      theme = "dark";
      defaultProvider = "openai-codex";
      defaultModel = "gpt-6-astra";
      defaultThinkingLevel = "high";
      hideThinkingBlock = true;
      defaultProjectTrust = "ask";
      packages = [
        "npm:@99percentpeople/pi-codex-api@0.4.0"
        "npm:@akepka/pi-cursor-cli-provider@0.10.1"
        "npm:@dietrichgebert/ponytail@4.9.0"
        "npm:@juicesharp/rpiv-ask-user-question@2.9.0"
      ];
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
    };
    xdgFiles = {
      "rpiv-ask-user-question/config.json" =
        (pkgs.formats.json { }).generate "rpiv-ask-user-question.json"
          {
            collapseKey = "ctrl+]";
          };
    };
  };
  cursorPolicy = { lib, ... }: {
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
