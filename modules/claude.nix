{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (config.fleet) domain;
  inherit (config.flake.modules.homeManager) claude;
  tokenNames = [
    "github-mcp-token"
    "grafana-mcp-token"
    "claude-token"
  ];
  attribution = {
    commit = "";
    pr = "";
  };
  tokens =
    owner:
    lib.genAttrs tokenNames (name: {
      inherit owner;
      sopsFile =
        if name == "claude-token" then ../secrets/shared/claude.yaml else ../secrets/shared/mcp.yaml;
    });
  deniedDirs = [
    "/run/secrets"
    "/run/secrets.d"
    "/private/var/run/secrets"
    "/private/var/run/secrets.d"
    "/run/user"
    "/run/dbus"
    "/run/tailscale"
    "/nix/var/nix/daemon-socket"
    "/run/cups"
    "/run/nscd"
    "/run/systemd"
    "/tmp/.X11-unix"
    "/persist"
  ];
  managedSettings =
    home:
    builtins.toJSON {
      permissions.disableBypassPermissionsMode = "disable";
      sandbox = {
        enabled = true;
        failIfUnavailable = true;
        allowUnsandboxedCommands = false;
        network.strictAllowlist = true;
        filesystem.denyRead = deniedDirs ++ [ "${home}/.bitwarden-ssh-agent.sock" ];
      };
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
  agentPlugins = pkgs: [
    "${(pkgs.callPackage ./cache-tax.pkg.nix { }).src}"
    "${(pkgs.callPackage ./ponytail.pkg.nix { }).src}"
    "${(pkgs.callPackage ./caveman.pkg.nix { }).src}"
  ];
  githubMcpArgs = [
    "stdio"
    "--read-only"
    "--toolsets=repos,pull_requests,actions"
  ];
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
    darwin.desktop.homebrew.casks = [ "claude" ];

    darwin.base =
      { config, pkgs, ... }:
      {
        home-manager.users.${config.system.primaryUser}.imports = [ claude ];
        sops.secrets = tokens config.system.primaryUser;
        nixpkgs.config.allowUnfreePackages = [
          "claude-code"
          "rtk"
        ];
        system.activationScripts.postActivation.text = ''
          install -d -m 0755 "/Library/Application Support/ClaudeCode"
          ln -sfn ${
            pkgs.writeText "claude-managed-settings.json" (
              managedSettings config.users.users.${config.system.primaryUser}.home
            )
          } "/Library/Application Support/ClaudeCode/managed-settings.json"
        '';
      };

    nixos.desktop =
      { config, pkgs, ... }:
      {
        home-manager.users.marcos.imports = [ claude ];
        sops.secrets = tokens "marcos";
        nixpkgs.config.allowUnfreePackages = [
          "claude-code"
          "rtk"
        ];
        boot.kernel.sysctl."dev.tty.legacy_tiocsti" = 0;
        environment = {
          systemPackages = [
            pkgs.bubblewrap
            pkgs.socat
          ];
          etc."claude-code/managed-settings.json".text = managedSettings config.users.users.marcos.home;
        };
      };

    nixos.claude-agent =
      { pkgs, ... }:
      let
        json = pkgs.formats.json { };
        plugin = pkgs.runCommand "claude-agent-plugin" { } ''
          install -Dm644 ${
            # Home Manager's name for its generated plugin, so tool names match the workstations'
            json.generate "plugin.json" { name = "hm"; }
          } $out/.claude-plugin/plugin.json
          install -Dm644 ${
            json.generate "mcp.json" {
              mcpServers = {
                nixos = {
                  type = "stdio";
                  command = lib.getExe pkgs.mcp-nixos;
                };
                github = {
                  type = "stdio";
                  command = lib.getExe pkgs.github-mcp-server;
                  args = githubMcpArgs;
                  env.GITHUB_PERSONAL_ACCESS_TOKEN = "\${GH_TOKEN:-}";
                };
              };
            }
          } $out/.mcp.json
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
              CAVEMAN_DEFAULT_MODE = "ultracave";
              PONYTAIL_DEFAULT_MODE = "ultra";
              CLAUDE_CODE_PLUGIN_DIRS = lib.concatStringsSep ":" ([ "${plugin}" ] ++ agentPlugins pkgs);
            };
            hooks.PreToolUse = [ (rtkHook pkgs) ];
          };
        };
      };

    homeManager.claude =
      {
        config,
        lib,
        osConfig,
        pkgs,
        ...
      }:
      let
        home = config.home.homeDirectory;
        inherit (config.programs.claude-code) configDir;
        dns = "169.254.1.1";
        ponytailLedger = "${config.xdg.configHome}/ponytail/band";
        readOnly = [
          builtins.storeDir
          "/etc"
          "/bin"
          "/usr"
          "/run/current-system"
        ]
        ++ map (name: osConfig.sops.secrets.${name}.path) tokenNames;
        readOnlyIfPresent = [
          "${home}/.gitconfig"
          "${config.xdg.configHome}/git"
          "${config.xdg.configHome}/ponytail"
          "${config.xdg.configHome}/caveman"
        ];
        keptEnv = lib.concatStringsSep "|" [
          "PATH"
          "HOME"
          "USER"
          "LOGNAME"
          "SHELL"
          "TERM"
          "TERM_PROGRAM(_VERSION)?"
          "COLORTERM"
          "LANG"
          "LANGUAGE"
          "LC_[A-Z_]+"
          "TZ"
          "LOCALE_ARCHIVE"
          "TERMINFO(_DIRS)?"
          "XDG_(CONFIG|DATA|STATE|CACHE)_HOME"
          "XDG_(CONFIG|DATA)_DIRS"
          "EDITOR"
          "VISUAL"
          "PAGER"
          "NIX_PATH"
          "NIX_PROFILES"
          "(NIX_)?SSL_CERT_FILE"
        ];
        withToken = pkgs.symlinkJoin {
          inherit (pkgs.claude-code) pname version meta;
          paths = [ pkgs.claude-code ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/claude --run ${lib.escapeShellArg ''
              if [ -r ${osConfig.sops.secrets.claude-token.path} ]; then
                CLAUDE_CODE_OAUTH_TOKEN=$(< ${osConfig.sops.secrets.claude-token.path})
                export CLAUDE_CODE_OAUTH_TOKEN
              fi
            ''}
          '';
        };
        jailed =
          inputs.jail-nix.lib.extend
            {
              inherit pkgs;
              basePermissions = [ ];
              bubblewrapPackage = pkgs.writeShellScriptBin "bwrap" ''
                exec ${lib.getExe' pkgs.passt "pasta"} --config-net --quiet \
                  --tcp-ports none --udp-ports none --tcp-ns none --udp-ns none \
                  --no-map-gw --dns-forward ${dns} -- \
                  ${lib.getExe pkgs.bubblewrap} "$@"
              '';
            }
            "claude"
            withToken
            (
              c:
              [
                c.no-new-session
                (c.share-ns "net")
                (c.unsafe-add-raw-args "--proc /proc --dev /dev --tmpfs /tmp --tmpfs /run --clearenv")
              ]
              ++ map c.readonly readOnly
              ++ [
                (c.tmpfs home)
                (c.readwrite configDir)
              ]
              ++ map c.try-readonly readOnlyIfPresent
              ++ [
                (c.readwrite ponytailLedger)
                (c.set-env "CLAUDE_CONFIG_DIR" configDir)
                (c.add-runtime ''
                  export PATH=${
                    lib.makeBinPath [
                      pkgs.coreutils
                      pkgs.git
                    ]
                  }:$PATH
                  dir=$(pwd -P)
                  binds=("$dir")
                  if top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null); then
                    top=$(realpath "$top")
                    common=$(realpath "$(git -C "$dir" rev-parse --git-common-dir)")
                    gitdir=$(realpath "$(git -C "$dir" rev-parse --git-dir)")
                    if [[ "$common" == "$top/.git" ]] ||
                      [[ "$gitdir" == "$common/worktrees/"* && "$(realpath "$(cat "$gitdir/gitdir" 2>/dev/null)" 2>/dev/null)" == "$top/.git" ]]; then
                      binds=("$top" "$common")
                    fi
                  fi
                  for b in "''${binds[@]}"; do
                    d="''${b%/}/"
                    for p in ${lib.escapeShellArgs deniedDirs}; do
                      if [[ "$p/" == "$d"* || "$d" == "$p/"* ]]; then
                        echo "claude: $b holds or sits in a path the jail hides" >&2
                        exit 1
                      fi
                    done
                    if [[ "${home}/" == "$d"* || "$d" == "${home}/."* ]]; then
                      echo "claude: $b holds or sits in a path the jail hides" >&2
                      exit 1
                    fi
                  done
                  mkdir -p "${configDir}" "${ponytailLedger}"
                  if [[ ! -e "${configDir}/.claude.json" && -e "${home}/.claude.json" ]]; then
                    mv "${home}/.claude.json" "${configDir}/.claude.json"
                  fi
                  RUNTIME_ARGS+=(--uid "$(id -u)" --gid "$(id -g)")
                  RUNTIME_ARGS+=(--ro-bind ${pkgs.writeText "resolv.conf" "nameserver ${dns}\n"} "$(readlink -f /etc/resolv.conf)")
                  for b in "''${binds[@]}"; do RUNTIME_ARGS+=(--bind "$b" "$b"); done
                  RUNTIME_ARGS+=(--chdir "$dir")
                  while IFS= read -r -d "" pair; do
                    name="''${pair%%=*}"
                    if [[ "$name" =~ ^(${keptEnv})$ ]]; then RUNTIME_ARGS+=(--setenv "$name" "''${pair#*=}"); fi
                  done < <(env -0)
                '')
              ]
            );
        jail = jailed.overrideAttrs { inherit (pkgs.claude-code) version; };
      in
      {
        home = {
          packages = [
            pkgs.nodejs
            pkgs.rtk
          ];
          file."${configDir}/.ponytail-band".text = "off";
        };
        xdg.configFile = {
          "ponytail/config.json".text = builtins.toJSON {
            defaultMode = "ultra";
            hideStatus = true;
          };
          "caveman/config.json".text = builtins.toJSON { defaultMode = "ultracave"; };
        };
        programs.mcp = {
          enable = true;
          servers = {
            nixos.command = lib.getExe pkgs.mcp-nixos;
            github = {
              command = lib.getExe pkgs.github-mcp-server;
              args = githubMcpArgs;
              env.GITHUB_PERSONAL_ACCESS_TOKEN.file = osConfig.sops.secrets.github-mcp-token.path;
            };
            grafana = {
              command = lib.getExe pkgs.mcp-grafana;
              args = [ "--disable-write" ];
              env = {
                GRAFANA_URL = "https://grafana.${domain}";
                GRAFANA_SERVICE_ACCOUNT_TOKEN.file = osConfig.sops.secrets.grafana-mcp-token.path;
              };
            };
          };
        };
        programs.claude-code = {
          enable = true;
          package = if pkgs.stdenv.hostPlatform.isLinux then jail else withToken;
          enableMcpIntegration = true;
          lspServers = lspServers pkgs;
          settings = {
            theme = "dark-ansi";
            inherit attribution;
            env = {
              RTK_SUPPRESS_HOOK_WARNING = "1";
              CLAUDE_CODE_PLUGIN_DIRS = lib.concatStringsSep ":" (
                agentPlugins pkgs
                ++ map (plugin: "${(pkgs.callPackage ./trailofbits-skills.pkg.nix { }).src}/plugins/${plugin}") [
                  "agentic-actions-auditor"
                  "c-review"
                  "modern-cpp"
                  "modern-python"
                  "rust-review"
                  "insecure-defaults"
                  "sharp-edges"
                  "supply-chain-risk-auditor"
                ]
                ++
                  map (plugin: "${(pkgs.callPackage ./claude-plugins-official.pkg.nix { }).src}/plugins/${plugin}")
                    [
                      "skill-creator"
                      "claude-md-management"
                    ]
              );
            };
            hooks.PreToolUse = [ (rtkHook pkgs) ];
            permissions = {
              defaultMode = "auto";
              blockReadsOutsideWorkingDirectories = true;
              allow = [
                "mcp__plugin_hm_nixos__nix"
                "mcp__plugin_hm_nixos__nix_versions"
              ]
              ++ map (tool: "mcp__plugin_hm_github__${tool}") [
                "get_*"
                "list_*"
                "search_*"
                "pull_request_read"
              ];
              deny = map (file: "Read(${file})") (
                lib.concatMap (path: [
                  "~/${path}"
                  "~/${path}/**"
                ]) (import ./_home-secrets.nix)
                ++ [
                  "~/.claude.json"
                  "~/${lib.removePrefix "${home}/" configDir}/.claude.json"
                  "~/Library/Keychains/**"
                  "~/Library/Application Support/sops/**"
                  "~/Library/Application Support/Bitwarden/**"
                  "~/Library/Application Support/Zen/**"
                  "~/Library/Application Support/Claude/**"
                  "~/.config/Bitwarden/**"
                  "~/.zen/**"
                  "~/.config/zen/**"
                ]
                ++ map (dir: "/${dir}/**") deniedDirs
              );
            };
          };
        };
      };
  };
}
