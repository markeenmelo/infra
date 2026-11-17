{
  config,
  lib,
  ...
}:
let
  inherit (config.fleet) domain;
  inherit (config.flake.modules.homeManager) claude;
  tokenNames = [
    "github-mcp-token"
    "grafana-mcp-token"
  ];
  tokens =
    owner:
    lib.genAttrs tokenNames (_: {
      inherit owner;
      sopsFile = ../secrets/shared/mcp.yaml;
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
        readOnly = lib.concatMapStringsSep " " (path: "--ro-bind ${path} ${path}") (
          [
            builtins.storeDir
            "/etc"
            "/bin"
            "/usr"
            "/run/current-system"
          ]
          ++ map (name: osConfig.sops.secrets.${name}.path) tokenNames
        );
        readOnlyIfPresent = lib.concatMapStringsSep " " (path: "--ro-bind-try ${path} ${path}") [
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
        jail = pkgs.writeShellApplication {
          name = "claude";
          derivationArgs = { inherit (pkgs.claude-code) version; };
          runtimeInputs = [
            pkgs.coreutils
            pkgs.git
          ];
          text = ''
            dir=$(pwd -P)
            binds=("$dir")
            if top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null); then
              binds=("$(realpath "$top")" "$(realpath "$(git -C "$dir" rev-parse --git-common-dir)")")
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
            bindArgs=()
            for b in "''${binds[@]}"; do bindArgs+=(--bind "$b" "$b"); done
            mkdir -p "${configDir}" "${ponytailLedger}"
            if [[ ! -e "${configDir}/.claude.json" && -e "${home}/.claude.json" ]]; then
              mv "${home}/.claude.json" "${configDir}/.claude.json"
            fi
            kept=(--clearenv)
            while IFS= read -r -d "" pair; do
              name="''${pair%%=*}"
              if [[ "$name" =~ ^(${keptEnv})$ ]]; then kept+=(--setenv "$name" "''${pair#*=}"); fi
            done < <(env -0)
            exec ${lib.getExe' pkgs.passt "pasta"} --config-net --quiet \
              --tcp-ports none --udp-ports none --tcp-ns none --udp-ns none \
              --no-map-gw --dns-forward ${dns} -- \
              ${lib.getExe pkgs.bubblewrap} \
              --unshare-all --unshare-user --share-net --die-with-parent \
              --uid "$(id -u)" --gid "$(id -g)" \
              --proc /proc --dev /dev --tmpfs /tmp --tmpfs /run \
              ${readOnly} \
              --ro-bind ${pkgs.writeText "resolv.conf" "nameserver ${dns}\n"} "$(readlink -f /etc/resolv.conf)" \
              --tmpfs "${home}" \
              --bind "${configDir}" "${configDir}" \
              ${readOnlyIfPresent} \
              --bind "${ponytailLedger}" "${ponytailLedger}" \
              "''${bindArgs[@]}" --chdir "$dir" \
              "''${kept[@]}" --setenv CLAUDE_CONFIG_DIR "${configDir}" \
              -- ${lib.getExe pkgs.claude-code} "$@"
          '';
        };
      in
      {
        home = {
          packages = [
            pkgs.nodejs
            pkgs.rtk
          ];
          file."${config.programs.claude-code.configDir}/.ponytail-band".text = "off";
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
              args = [
                "stdio"
                "--read-only"
                "--toolsets=repos,pull_requests,actions"
              ];
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
          package = lib.mkIf pkgs.stdenv.hostPlatform.isLinux jail;
          enableMcpIntegration = true;
          lspServers = {
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
          settings = {
            theme = "dark-ansi";
            attribution = {
              commit = "";
              pr = "";
            };
            env = {
              RTK_SUPPRESS_HOOK_WARNING = "1";
              CLAUDE_CODE_PLUGIN_DIRS = lib.concatStringsSep ":" (
                [
                  "${(pkgs.callPackage ./cache-tax.pkg.nix { }).src}"
                  "${(pkgs.callPackage ./ponytail.pkg.nix { }).src}"
                  "${(pkgs.callPackage ./caveman.pkg.nix { }).src}"
                ]
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
            hooks.PreToolUse = [
              {
                matcher = "Bash";
                hooks = [
                  {
                    type = "command";
                    command = "${lib.getExe pkgs.rtk} hook claude";
                  }
                ];
              }
            ];
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
                  "~/${lib.removePrefix "${config.home.homeDirectory}/" configDir}/.claude.json"
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
