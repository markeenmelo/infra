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
          rev = "0a4dd63ad4541f4f655c4108a295916f3c1d8fda";
          hash = "sha256-8cYggVltBAlZ/Zj4pl1bOu7mQdZFXCmDGW4RSpvRA+w=";
        };
      in
      {
        home.packages = [ pkgs.nodejs ];

        programs = {
          pi-coding-agent = {
            enable = true;
            extraPackages = with pkgs; [
              gh
              git
            ];
            settings = {
              lastChangelogVersion = pkgs.pi-coding-agent.version;
              defaultProvider = "openai-codex";
              defaultModel = "gpt-6-astra";
              defaultThinkingLevel = "high";
              defaultProjectTrust = "ask";
              packages = [
                "npm:@dietrichgebert/ponytail@4.9.0"
                "npm:@janvitos/pi-plan-build@0.1.98"
                "npm:@juicesharp/rpiv-ask-user-question@2.10.1"
                "npm:pi-claude-bridge@0.7.0"
                "npm:pi-mcp-adapter@2.33.0"
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
