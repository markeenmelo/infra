{ config, lib, ... }:
let
  nativeFiles = [
    ".pi/agent/settings.json"
    ".pi/agent/99extensions.json"
    ".pi/agent/extensions/pi-tool-repair.json"
    ".config/rtk/config.toml"
    ".config/rpiv-ask-user-question/config.json"
  ];
  nativePolicy =
    lib.all
      (
        track:
        let
          fixture = config.fleet.validation.fixtureFor track "uefi" [
            "bastion-disko"
            "persistence"
            "access"
            "agents"
          ];
          cfg = fixture.config;
        in
        !(cfg ? home-manager)
        && lib.all (a: a.assertion) cfg.assertions
        && lib.elem fixture.pkgs.pi-coding-agent cfg.environment.systemPackages
        && lib.elem fixture.pkgs.rtk cfg.environment.systemPackages
        && cfg.environment.sessionVariables.RTK_TELEMETRY_DISABLED == "1"
        && lib.all (
          name:
          cfg.environment.etc ? "fleet-agents/${name}"
          && lib.elem "L %h/${name} - - - - /etc/fleet-agents/${name}" cfg.systemd.user.tmpfiles.rules
        ) nativeFiles
        && !(lib.any (rule: lib.hasPrefix "L+ " rule) cfg.systemd.user.tmpfiles.rules)
      )
      [
        "stable"
        "unstable"
      ];
  check =
    name: target: sources:
    let
      inherit (target) pkgs;
      inherit (pkgs) lib;
    in
    pkgs.runCommand name
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
        cp ${sources.settings} "$PI_CODING_AGENT_DIR/settings.json"
        cp ${sources.rtk} "$XDG_CONFIG_HOME/rtk/config.toml"
        cd "$TMPDIR/work"
        # Both pins may write version output to stderr without a TTY.
        version=$(env -i HOME="$HOME" PATH=${pkgs.coreutils}/bin ${pkgs.pi-coding-agent}/bin/pi --version 2>&1)
        test "$version" = '${pkgs.pi-coding-agent.version}'
        ${lib.getExe pkgs.nodejs} ${./assets/test-extensions.mjs} \
          ${pkgs.pi-coding-agent}/lib/node_modules/pi-monorepo \
          ${sources.codex} ${sources.repair}
        touch "$out"
      '';
in
{
  perSystem =
    _:
    let
      thinkpad = config.flake.fleetConfigurations.thinkpad;
      home = thinkpad.config.home-manager.users.marcos;
      bastion = config.flake.fleetConfigurations.bastion;
      etc = bastion.config.environment.etc;
    in
    {
      checks.pi-extensions = check "pi-extensions" thinkpad {
        settings = home.home.file."${home.programs.pi-coding-agent.configDir}/settings.json".source;
        rtk = home.xdg.configFile."rtk/config.toml".source;
        codex = home.home.file.".pi/agent/99extensions.json".source;
        repair = home.home.file.".pi/agent/extensions/pi-tool-repair.json".source;
      };
      checks.bastion-pi =
        assert lib.assertMsg nativePolicy
          "Native agents must preserve own-track packages and non-forcing public configuration without Home Manager on both tracks";
        check "bastion-pi" bastion {
          settings = etc."fleet-agents/.pi/agent/settings.json".source;
          rtk = etc."fleet-agents/.config/rtk/config.toml".source;
          codex = etc."fleet-agents/.pi/agent/99extensions.json".source;
          repair = etc."fleet-agents/.pi/agent/extensions/pi-tool-repair.json".source;
        };
    };
}
