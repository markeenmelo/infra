{
  config,
  inputs,
  lib,
  ...
}:
let
  fixtureFor = config.fleet.validation.fixtureFor;
  # Force import collection, not a toplevel that can fail on unrelated missing
  # options/facts or native stable API differences. Test both sides of the guard.
  desktopImports =
    track:
    (lib.evalModules {
      class = "nixos";
      specialArgs.modulesPath = "${
        if track == "stable" then inputs.nixpkgs-stable else inputs.nixpkgs
      }/nixos/modules";
      modules = [ config.flake.modules.nixos.desktop ];
    }).graph;
  desktopFixtures = lib.genAttrs [ "unstable" ] (
    track:
    fixtureFor track "uefi" [
      "thinkpad-disko"
      "ssh"
      "desktop"
      "persistence"
      "access"
      "workstation"
      "laptop"
    ]
  );
  desktopReport = lib.mapAttrs (
    track: fixture:
    let
      cfg = fixture.config;
      home = cfg.home-manager.users.fixture-admin;
      # Assertion failures are data on config.assertions; the NixOS toplevel
      # throws exactly when one is false. Force only the assertion booleans:
      # upstream messages may legitimately throw while their assertion passes,
      # because the toplevel renders failed messages only.
      rejected =
        module:
        let
          broken = (fixture.extendModules { modules = [ module ]; }).config;
          forced = builtins.tryEval (lib.all (a: a.assertion) broken.assertions);
        in
        !forced.success || !forced.value;
    in
    assert lib.assertMsg
      (
        cfg.fleet.bootstrap.missing == [ ]
        && lib.all (a: a.assertion) cfg.assertions
        && home.warnings == [ ]
        && cfg.home-manager.useGlobalPkgs
        && cfg.home-manager.useUserPackages
        && cfg.home-manager.backupFileExtension == null
        && builtins.attrNames cfg.home-manager.extraSpecialArgs == [ "nixosConfig" ]
        && !home.home.version.isReleaseBranch
        && lib.elem fixture.pkgs.noctalia home.home.packages
        && home.programs.direnv.enable
        && cfg.programs.hyprland.package.version == fixture.pkgs.hyprland.version
        && cfg.hardware.graphics.enable
        && !cfg.hardware.graphics.enable32Bit
        && cfg.programs.hyprland.withUWSM
        && cfg.programs.uwsm.enable
        &&
          cfg.programs.uwsm.waylandCompositors.hyprland.binPath == "/run/current-system/sw/bin/start-hyprland"
        && cfg.services.greetd.enable
        && cfg.services.displayManager.noctalia-greeter.enable
        && !cfg.services.greetd.useTextGreeter
        && cfg.services.fprintd.enable
        && cfg.security.pam.services.greetd.rules.auth.login.modulePath == "noctalia-greetd"
        &&
          cfg.security.pam.services.noctalia-greetd.rules.auth.unix.order
          < cfg.security.pam.services.noctalia-greetd.rules.auth.fprintd.order
        &&
          cfg.security.pam.services.sudo.rules.auth.unix.order
          < cfg.security.pam.services.sudo.rules.auth.fprintd.order
        && cfg.security.pam.services.noctalia-greetd.rules.auth.unix-early.enable
        && cfg.security.pam.services.noctalia-greetd.rules.auth.gnome_keyring.enable
        && cfg.security.pam.services.noctalia-greetd.rules.auth.unix.settings.use_first_pass
        && !cfg.security.pam.services.noctalia-greetd.rules.auth.unix.settings.try_first_pass
        && cfg.security.pam.services.greetd.rules.session.gnome_keyring.settings.auto_start
        && cfg.security.pam.services.noctalia-greetd.rules.auth.deny.enable
        && cfg.security.pam.services.sudo.rules.auth.deny.enable
        && !cfg.security.pam.services.noctalia-greetd.allowNullPassword
        && !cfg.security.pam.services.sudo.allowNullPassword
        && !cfg.security.pam.services.login.fprintAuth
        && !cfg.security.pam.services.sshd.fprintAuth
        && !cfg.services.gnome.gcr-ssh-agent.enable
        && !(cfg.services.greetd.settings ? initial_session)
        && !cfg.services.xserver.enable
        && cfg.systemd.enableEmergencyMode
        && cfg.services.pipewire.enable
        && cfg.services.pipewire.pulse.enable
        && cfg.services.gnome.gnome-keyring.enable
        && cfg.xdg.portal.config.hyprland."org.freedesktop.impl.portal.FileChooser" == "gtk"
        && home.systemd.user.services.noctalia.Unit.PartOf == [ "graphical-session.target" ]
        && home.systemd.user.services.noctalia.Service.ExecStart == [ (lib.getExe fixture.pkgs.noctalia) ]
        &&
          home.systemd.user.services.noctalia.Service.Environment == [
            "NOCTALIA_CONFIG_HOME=${home.xdg.configHome}/fleet-desktop"
            "NOCTALIA_STATE_HOME=${home.xdg.stateHome}/fleet-desktop"
            "NOCTALIA_DATA_HOME=${home.xdg.dataHome}/fleet-desktop"
          ]
        && home.xdg.configFile."noctalia/config.toml".target == ".config/fleet-desktop/noctalia/config.toml"
        && home.programs.noctalia.enable
        && home.programs.noctalia.settings.lockscreen.fingerprint
        && !home.programs.noctalia.settings.lockscreen.allow_empty_password
        && home.wayland.windowManager.hyprland.configType == "lua"
        && !home.wayland.windowManager.hyprland.systemd.enable
        && home.programs.ghostty.enable
        && home.programs.herdr.enable
        && home.programs.zed-editor.enable
        && home.programs.pi-coding-agent.enable
        && !home.programs.foot.enable
        && !home.programs.firefox.enable
        && home.sshAuthSock.enable
        && home.xdg.autostart.enable
        && !home.xdg.autostart.readOnly
        && home.services.kdeconnect.enable
        && !home.services.network-manager-applet.enable
        && lib.all (file: !file.force) (lib.attrValues home.home.file)
        && home.home.fileActivator == "legacy"
        && !(home.systemd.user.services ? hyprland)
        && !(home.systemd.user.services ? hypridle)
        && !(lib.hasInfix "AQ_DRM_DEVICES" home.xdg.configFile."hypr/hyprland.lua".text)
        && !(lib.hasInfix "__GLX_VENDOR_LIBRARY_NAME" home.xdg.configFile."hypr/hyprland.lua".text)
      )
      "${track}: desktop/Home Manager policy regressed; blockers: ${builtins.toJSON cfg.fleet.bootstrap.missing}; assertions: ${
        builtins.toJSON (map (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions))
      }";
    assert lib.assertMsg (
      rejected { fleet.desktop.reviewed = lib.mkForce false; }
      && rejected { security.pam.services.noctalia-greetd.allowNullPassword = lib.mkForce true; }
      && rejected { security.pam.services.sudo.rules.auth.deny.enable = lib.mkForce false; }
      && rejected { security.pam.services.sshd.fprintAuth = true; }
      && rejected {
        services.greetd.settings.initial_session = {
          command = "false";
          user = "fixture-admin";
        };
      }
    ) "${track}: desktop review and authenticated login must not be bypassed";
    {
      toplevel = cfg.system.build.toplevel.drvPath;
      homeActivation = home.home.activationPackage.drvPath;
      hyprland = cfg.programs.hyprland.package.version;
      noctalia = fixture.pkgs.noctalia.version;
      homeManagerRevision = inputs.home-manager.rev;
      unreviewedDesktopRejected = true;
      autologinRejected = true;
      unsafePamRejected = true;
    }
  ) desktopFixtures;
  desktopConfigCheck =
    name: system: user:
    let
      cfg = system.config;
      home = cfg.home-manager.users.${user};
      browser = lib.findFirst (package: (package.pname or "") == "zen-browser") null home.home.packages;
    in
    assert lib.assertMsg (
      lib.elem system.pkgs.nerd-fonts.jetbrains-mono home.home.packages
      && !(lib.elem system.pkgs.jetbrains-mono home.home.packages)
      && !(lib.elem system.pkgs.jetbrains-mono home.programs.zed-editor.extraPackages)
      && home.fonts.fontconfig.defaultFonts.monospace == [ "JetBrainsMono Nerd Font" ]
      && home.programs.ghostty.settings.font-family == [ "JetBrainsMono Nerd Font" ]
      && home.programs.zed-editor.userSettings.buffer_font_family == "JetBrainsMono Nerd Font"
      && home.programs.zed-editor.userSettings.ui_font_family == "JetBrainsMono Nerd Font"
      && home.programs.zed-editor.userSettings.terminal.font_family == "JetBrainsMono Nerd Font"
      && !home.programs.zed-editor.userSettings.search.search_on_type
      && cfg.fonts.fontconfig.defaultFonts.emoji == [ "Noto Color Emoji" ]
    ) "${name}: font policy or explicit-submit Zed search behavior regressed";
    system.pkgs.runCommand "${name}-desktop-config" { } ''
      export HOME="$TMPDIR/home"
      export XDG_RUNTIME_DIR="$TMPDIR/runtime"
      export XDG_CONFIG_HOME="$HOME/.config"
      mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
      chmod 700 "$XDG_RUNTIME_DIR"
      # This upstream mode parses the config without starting a compositor.
      ${lib.getExe cfg.programs.hyprland.package} --verify-config --config ${
        home.xdg.configFile."hypr/hyprland.lua".source
      }
      # Native HM validation is retained, plus a stricter warning gate: upstream
      # exits zero even for ignored/obsolete settings. Neither starts a session.
      ${lib.getExe system.pkgs.noctalia} config validate ${
        home.xdg.configFile."noctalia/config.toml".source
      } > noctalia.log 2>&1
      cat noctalia.log
      if grep -E 'WARN|ERROR' noctalia.log; then exit 1; fi
      install -Dm644 ${
        home.xdg.configFile."ghostty/themes/OLED Graphite".source
      } "$XDG_CONFIG_HOME/ghostty/themes/OLED Graphite"
      ${lib.getExe system.pkgs.ghostty} +validate-config --config-file=${
        home.xdg.configFile."ghostty/config".source
      }
      HERDR_CONFIG_PATH=${home.xdg.configFile."herdr/config.toml".source} \
        ${lib.getExe system.pkgs.herdr} config check
      ${lib.getExe system.pkgs.python3} - <<'PY'
      import json, tomllib
      with open("${
        cfg.systemd.tmpfiles.settings."10-noctalia-greeter"."/var/lib/noctalia-greeter/greeter.toml"."L+".argument
      }", "rb") as stream:
          greeter = tomllib.load(stream)
      assert greeter["session"]["default"] == "Hyprland (UWSM)"
      assert greeter["auth"]["allow_empty_password"] is True  # UI submission only, not PAM nullok.
      for filename in ["${home.xdg.configFile."zed/settings.json".source}", "${
        home.home.file."${home.programs.pi-coding-agent.configDir}/settings.json".source
      }"]:
          with open(filename) as stream: json.load(stream)
      PY
      grep -qx 'Hidden=true' ${home.xdg.configFile.autostart.source}/nm-applet.desktop
      grep -qx 'Hidden=true' ${home.xdg.configFile.autostart.source}/org.kde.kdeconnect.daemon.desktop
      test -x ${browser}/bin/zen
      test -s ${browser}/share/applications/zen.desktop
      # The sandbox has no system fontconfig file; use the package's supplied
      # config for this direct TTF inspection, not the machine's /etc.
      export FONTCONFIG_FILE=${system.pkgs.fontconfig.out}/etc/fonts/fonts.conf
      find ${system.pkgs.nerd-fonts.jetbrains-mono} -iname '*Regular.ttf' \
        -exec ${lib.getExe' system.pkgs.fontconfig "fc-scan"} --format '%{family}\n' {} + > font-families
      grep -Eq '^JetBrainsMono Nerd Font(,|$)' font-families
      ${lib.optionalString cfg.programs.nh.enable ''
        # Help/version only: no rebuild, activation, target contact or cleanup.
        ${lib.getExe cfg.programs.nh.package} --version
        ${lib.getExe cfg.programs.nh.package} os build --help > /dev/null
      ''}
      touch "$out"
    '';
in
{
  fleet.validation.hostChecks.desktop =
    { name, system, ... }:
    let
      cfg = system.config;
    in
    assert lib.assertMsg (
      if name == "thinkpad" then
        cfg.programs.hyprland.enable
        && cfg.programs.hyprland.withUWSM
        && cfg.services.greetd.enable
        && cfg.services.displayManager.enable
        && !(cfg.services.greetd.settings ? initial_session)
        && builtins.attrNames cfg.home-manager.users == [ "marcos" ]
        && cfg.home-manager.useGlobalPkgs
        && cfg.home-manager.useUserPackages
        && cfg.home-manager.users.marcos.home.stateVersion == "26.05"
        && !cfg.home-manager.users.marcos.home.version.isReleaseBranch
        && cfg.home-manager.users.marcos.warnings == [ ]
        && !cfg.hardware.graphics.enable32Bit
        && cfg.hardware.bluetooth.enable
        && cfg.hardware.bluetooth.powerOnBoot
        && cfg.home-manager.users.marcos.wayland.windowManager.hyprland.settings.config.input.touchpad.disable_while_typing
        && !cfg.home-manager.users.marcos.programs.noctalia.settings.bar.main.auto_hide
        && cfg.home-manager.users.marcos.programs.pi-coding-agent.settings.defaultProvider == "openai-codex"
        && cfg.home-manager.users.marcos.programs.pi-coding-agent.settings.defaultModel == "gpt-6-astra"
        && lib.all (module: lib.elem module cfg.boot.initrd.availableKernelModules) [
          "xhci_pci"
          "thunderbolt"
          "nvme"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ]
        && lib.elem "dm-snapshot" cfg.boot.initrd.kernelModules
        && lib.elem "kvm-intel" cfg.boot.kernelModules
        && !(lib.elem "nvidia" cfg.services.xserver.videoDrivers)
        &&
          lib.all
            (marker: lib.hasInfix marker cfg.home-manager.users.marcos.xdg.configFile."hypr/hyprland.lua".text)
            [
              "1920x1200@60.003"
              "fleet-output-policy"
              "switch:on:Lid Switch"
              "switch:off:Lid Switch"
              "hyprland.start"
            ]
      else
        !cfg.programs.hyprland.enable
        && !cfg.services.displayManager.enable
        && !cfg.services.greetd.enable
        && !(system.options ? home-manager)
        && !cfg.services.fprintd.enable
        && !cfg.hardware.bluetooth.enable
        && !cfg.services.printing.enable
        && !cfg.programs.kdeconnect.enable
    ) "${name}: only ThinkPad may opt into the new Intel-first desktop; other hosts remain headless";
    true;
  fleet.validation.fixtureModules.desktop = _: {
    fleet.desktop.reviewed = true;
    home-manager.users.fixture-admin.home.stateVersion = "26.05";
  };
  flake.validation.desktop =
    assert builtins.deepSeq (desktopImports "unstable") true;
    assert lib.assertMsg (
      !(builtins.tryEval (builtins.deepSeq (desktopImports "stable") true)).success
    ) "The desktop must reject unsupported stable imports before option checking.";
    desktopReport;
  perSystem.checks = {
    thinkpad-desktop-config =
      desktopConfigCheck "thinkpad" config.flake.fleetConfigurations.thinkpad
        "marcos";
  }
  // lib.mapAttrs' (
    track: fixture:
    lib.nameValuePair "${track}-desktop-config" (desktopConfigCheck track fixture "fixture-admin")
  ) desktopFixtures;
}
