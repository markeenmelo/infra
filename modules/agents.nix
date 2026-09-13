{
  flake.modules.homeManager.desktop =
    { pkgs, ... }:
    {
      programs.pi-coding-agent = {
        enable = true;
        extraPackages = with pkgs; [
          gh
          git
          nodejs
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
    };
}
