{
  flake.modules = {
    nixos.desktop =
      { lib, ... }:
      {
        nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-code";
      };

    homeManager.desktop =
      { pkgs, ... }:
      let
        ponytail = pkgs.fetchFromGitHub {
          owner = "DietrichGebert";
          repo = "ponytail";
          rev = "e3ba2aa6f1e6f0bc4d69eb09c9f0d0a93af56156";
          hash = "sha256-PES5XrSYx0VBXWVHEDRykGy0SAmJfV/luzy8Gfg0aAQ=";
        };
      in
      {
        home.packages = [ pkgs.nodejs ];

        programs = {
          pi-coding-agent = {
            enable = true;
            settings = {
              lastChangelogVersion = pkgs.pi-coding-agent.version;
              defaultProvider = "openai-codex";
              defaultModel = "gpt-6-astra";
              defaultThinkingLevel = "high";
              defaultProjectTrust = "ask";
              packages = [
                "npm:@99percentpeople/pi-codex-api@0.4.0"
                "npm:@dietrichgebert/ponytail@4.10.0"
                "npm:@janvitos/pi-plan-build@0.1.101"
                "npm:@juicesharp/rpiv-ask-user-question@2.10.1"
                "npm:pi-claude-bridge@0.7.0"
                "npm:pi-mcp-adapter@2.34.0"
                "npm:pi-powerline-footer@0.17.1"
                "npm:pi-simplify@0.2.3"
                "npm:pi-web-access@0.29.0"
              ];
            };
          };

          claude-code = {
            enable = true;
            plugins.ponytail = ponytail;
            settings = {
              model = "opus";
              effortLevel = "xhigh";
              permissions.defaultMode = "plan";
            };
          };
        };
      };
  };
}
