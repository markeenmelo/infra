{ config, lib, ... }:
let
  grafana = {
    args = [
      "--disable-write"
      "--enabled-tools=search,datasource,prometheus,loki,alerting,dashboard,folder,annotations,navigation,api"
    ];
    url = "https://grafana.${config.fleet.domain}";
  };
  attribution = {
    commit = "";
    pr = "";
  };
  lspServers = pkgs: {
    nix = {
      command = lib.getExe pkgs.nixd;
      extensionToLanguage.".nix" = "nix";
    };
    clangd = {
      command = lib.getExe' pkgs.clang-tools "clangd";
      extensionToLanguage = {
        ".c" = "c";
        ".h" = "c";
        ".cpp" = "cpp";
        ".cc" = "cpp";
        ".hpp" = "cpp";
      };
    };
    python = {
      command = lib.getExe' pkgs.basedpyright "basedpyright-langserver";
      args = [ "--stdio" ];
      extensionToLanguage.".py" = "python";
    };
    typescript = {
      command = lib.getExe pkgs.typescript-language-server;
      args = [ "--stdio" ];
      extensionToLanguage = {
        ".ts" = "typescript";
        ".tsx" = "typescriptreact";
        ".js" = "javascript";
        ".jsx" = "javascriptreact";
        ".mjs" = "javascript";
      };
    };
    lua = {
      command = lib.getExe pkgs.lua-language-server;
      extensionToLanguage.".lua" = "lua";
    };
    terraform = {
      command = lib.getExe pkgs.terraform-ls;
      args = [ "serve" ];
      extensionToLanguage = {
        ".tf" = "terraform";
        ".tofu" = "terraform";
      };
    };
    bash = {
      command = lib.getExe pkgs.bash-language-server;
      args = [ "start" ];
      extensionToLanguage = {
        ".sh" = "shellscript";
        ".bash" = "shellscript";
      };
    };
    rust = {
      command = lib.getExe pkgs.rust-analyzer;
      extensionToLanguage.".rs" = "rust";
    };
  };
  agentPlugins =
    pkgs:
    [
      "${(pkgs.callPackage ./ponytail.pkg.nix { }).src}"
      "${(pkgs.callPackage ./caveman.pkg.nix { }).src}"
    ]
    ++ map (plugin: "${(pkgs.callPackage ./trailofbits-skills.pkg.nix { }).src}/plugins/${plugin}") [
      "insecure-defaults"
      "sharp-edges"
    ]
    ++
      map (plugin: "${(pkgs.callPackage ./claude-plugins-official.pkg.nix { }).src}/plugins/${plugin}")
        [
          "skill-creator"
          "claude-md-management"
        ];
  mcpServers = pkgs: {
    nixos = {
      type = "stdio";
      command = lib.getExe pkgs.mcp-nixos;
    };
    grafana = {
      type = "stdio";
      command = lib.getExe pkgs.mcp-grafana;
      inherit (grafana) args;
      env = {
        GRAFANA_URL = grafana.url;
        GRAFANA_SERVICE_ACCOUNT_TOKEN = "\${GRAFANA_SERVICE_ACCOUNT_TOKEN}";
      };
    };
  };
  rtkHook = pkgs: {
    matcher = "Bash";
    hooks = [
      {
        type = "command";
        command = "${lib.getExe pkgs.rtk} hook claude";
      }
    ];
  };
in
{
  flake.modules = {
    nixos.claude-agent =
      { pkgs, ... }:
      let
        json = pkgs.formats.json { };
        plugin = pkgs.runCommand "claude-agent-plugin" { } ''
          install -Dm644 ${
            # the name Home Manager gave its generated plugin, kept so the tools stay mcp__plugin_hm_*
            json.generate "plugin.json" { name = "hm"; }
          } $out/.claude-plugin/plugin.json
          install -Dm644 ${json.generate "mcp.json" { mcpServers = mcpServers pkgs; }} $out/.mcp.json
          install -Dm644 ${json.generate "lsp.json" (lspServers pkgs)} $out/.lsp.json
        '';
      in
      {
        environment = {
          systemPackages = [
            pkgs.claude-code
            pkgs.nodejs
            pkgs.rtk
          ];
          etc."claude-code/managed-settings.json".text = builtins.toJSON {
            inherit attribution;
            env = {
              RTK_SUPPRESS_HOOK_WARNING = "1";
              ANTHROPIC_MODEL = "claude-opus-5-5";
              CAVEMAN_DEFAULT_MODE = "ultracave";
              PONYTAIL_DEFAULT_MODE = "ultra";
              CLAUDE_CODE_PLUGIN_DIRS = lib.concatStringsSep ":" ([ "${plugin}" ] ++ agentPlugins pkgs);
            };
            hooks.PreToolUse = [ (rtkHook pkgs) ];
          };
        };
      };

    homeManager.agent-tools =
      { config, pkgs, ... }:
      {
        programs.pi-coding-agent = {
          enable = true;
          settings = {
            enableInstallTelemetry = false;
            defaultProvider = "kimi-coding";
            defaultModel = "k3.1-pro";
          };
        };
        home.file."${config.programs.pi-coding-agent.configDir}/mcp.json".source =
          (pkgs.formats.json { }).generate "pi-mcp.json"
            { mcpServers = mcpServers pkgs; };
      };
  };
}
