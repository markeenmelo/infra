{ config, ... }:
{
  perSystem =
    _:
    let
      thinkpad = config.flake.fleetConfigurations.thinkpad;
      inherit (thinkpad) pkgs;
      home = thinkpad.config.home-manager.users.marcos;
      settings = home.home.file."${home.programs.pi-coding-agent.configDir}/settings.json".source;
      codex = home.home.file.".pi/agent/99extensions.json".source;
    in
    {
      checks.pi-extensions =
        assert pkgs.lib.assertMsg (
          !(home.home.file ? ".pi/agent/extensions/pi-tool-repair.json")
          && !(home.xdg.configFile ? "rtk/config.toml")
          && !(home.home.sessionVariables ? RTK_TELEMETRY_DISABLED)
          && builtins.all (package: pkgs.lib.getName package != "rtk") (
            home.home.packages ++ home.programs.pi-coding-agent.extraPackages
          )
        ) "Removed Pi extensions must not leave managed configuration or RTK packages behind.";
        pkgs.runCommand "pi-extensions"
          {
            nativeBuildInputs = [ pkgs.nodejs ];
          }
          ''
            export HOME="$TMPDIR/home"
            export XDG_CONFIG_HOME="$HOME/.config"
            export PI_CODING_AGENT_DIR="$HOME/.pi/agent"
            export PI_OFFLINE=1
            mkdir -p "$PI_CODING_AGENT_DIR" "$TMPDIR/work"
            cp ${settings} "$PI_CODING_AGENT_DIR/settings.json"
            cd "$TMPDIR/work"
            version=$(env -i HOME="$HOME" PATH=${pkgs.coreutils}/bin ${pkgs.pi-coding-agent}/bin/pi --version 2>&1)
            test "$version" = '${pkgs.pi-coding-agent.version}'
            node ${./assets/test-extensions.mjs} ${codex}
            touch "$out"
          '';
    };
}
