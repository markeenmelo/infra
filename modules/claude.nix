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
        hiddenEnv = lib.concatMapStringsSep " " (name: "--unsetenv ${name}") [
          "SSH_AUTH_SOCK"
          "DBUS_SESSION_BUS_ADDRESS"
          "XDG_RUNTIME_DIR"
          "WAYLAND_DISPLAY"
          "DISPLAY"
        ];
        jail = pkgs.writeShellApplication {
          name = "claude";
          derivationArgs = { inherit (pkgs.claude-code) version; };
          runtimeInputs = [ pkgs.coreutils ];
          text = ''
            if [[ "${home}/" == "''${PWD%/}/"* ]]; then
              echo "claude: $PWD holds the home directory, which the jail would expose" >&2
              exit 1
            fi
            mkdir -p "${configDir}" "${ponytailLedger}"
            [[ -e "${home}/.claude.json" ]] || echo '{}' >"${home}/.claude.json"
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
              --bind "${home}/.claude.json" "${home}/.claude.json" \
              ${readOnlyIfPresent} \
              --bind "${ponytailLedger}" "${ponytailLedger}" \
              --bind "$PWD" "$PWD" --chdir "$PWD" \
              ${hiddenEnv} \
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
