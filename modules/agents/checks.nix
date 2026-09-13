{ config, ... }:
{
  perSystem =
    _:
    let
      thinkpad = config.flake.fleetConfigurations.thinkpad;
      inherit (thinkpad) pkgs;
      home = thinkpad.config.home-manager.users.marcos;
      settings = home.home.file."${home.programs.pi-coding-agent.configDir}/settings.json".source;
      rtkConfig = home.xdg.configFile."rtk/config.toml".source;
      codex = home.home.file.".pi/agent/99extensions.json".source;
      repair = home.home.file.".pi/agent/extensions/pi-tool-repair.json".source;
    in
    {
      checks.pi-extensions =
        pkgs.runCommand "pi-extensions"
          {
            nativeBuildInputs = with pkgs; [
              nodejs
              gh
              git
              rtk
            ];
          }
          ''
            export HOME="$TMPDIR/home"
            export XDG_CONFIG_HOME="$HOME/.config"
            export PI_CODING_AGENT_DIR="$HOME/.pi/agent"
            export PI_OFFLINE=1
            export RTK_TELEMETRY_DISABLED=1
            mkdir -p "$PI_CODING_AGENT_DIR" "$TMPDIR/work" "$XDG_CONFIG_HOME/rtk"
            cp ${settings} "$PI_CODING_AGENT_DIR/settings.json"
            cp ${rtkConfig} "$XDG_CONFIG_HOME/rtk/config.toml"
            cd "$TMPDIR/work"
            # Native Pi may write version output to stderr without a TTY.
            version=$(env -i HOME="$HOME" PATH=${pkgs.coreutils}/bin ${pkgs.pi-coding-agent}/bin/pi --version 2>&1)
            test "$version" = '${pkgs.pi-coding-agent.version}'
            ${pkgs.lib.getExe pkgs.nodejs} ${./assets/test-extensions.mjs} \
              ${pkgs.pi-coding-agent}/lib/node_modules/pi-monorepo \
              ${codex} ${repair}
            touch "$out"
          '';
    };
}
