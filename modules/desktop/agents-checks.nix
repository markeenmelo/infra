{ config, lib, ... }:
{
  # Keep Pi's integration checks separate from the concurrently edited fleet oracle.
  perSystem =
    _:
    let
      target = config.flake.fleetConfigurations.thinkpad;
      inherit (target) pkgs;
      home = target.config.home-manager.users.marcos;
      pi = home.programs.pi-coding-agent;
    in
    {
      checks.pi-extensions =
        pkgs.runCommand "pi-extensions"
          {
            nativeBuildInputs = pi.extraPackages;
          }
          ''
            export HOME="$TMPDIR/home"
            export XDG_CONFIG_HOME="$HOME/.config"
            export PI_CODING_AGENT_DIR="$HOME/.pi/agent"
            export PI_OFFLINE=1
            export RTK_TELEMETRY_DISABLED=1
            mkdir -p "$PI_CODING_AGENT_DIR/extensions/subagent" "$TMPDIR/work" \
              "$XDG_CONFIG_HOME/ponytail" "$XDG_CONFIG_HOME/rtk" "$XDG_CONFIG_HOME/pi"
            cp ${home.home.file."${pi.configDir}/settings.json".source} "$PI_CODING_AGENT_DIR/settings.json"
            cp ${home.home.file.".pi/agent/web-search.json".source} "$PI_CODING_AGENT_DIR/web-search.json"
            cp ${home.xdg.configFile."pi/web-search.json".source} "$XDG_CONFIG_HOME/pi/web-search.json"
            cp ${home.home.file.".pi/agent/i-have-adhd.json".source} "$PI_CODING_AGENT_DIR/i-have-adhd.json"
            cp ${home.xdg.configFile."ponytail/config.json".source} "$XDG_CONFIG_HOME/ponytail/config.json"
            cp ${home.xdg.configFile."rtk/config.toml".source} "$XDG_CONFIG_HOME/rtk/config.toml"
            cp ${
              home.home.file.".pi/agent/extensions/subagent/config.json".source
            } "$PI_CODING_AGENT_DIR/extensions/subagent/config.json"
            cd "$TMPDIR/work"
            ${lib.getExe pkgs.nodejs} ${./assets/pi/test-extensions.mjs} \
              ${pkgs.pi-coding-agent}/lib/node_modules/pi-monorepo \
              ${builtins.head pi.settings.packages}
            touch "$out"
          '';
    };
}
