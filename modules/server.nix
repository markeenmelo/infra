{ config, lib, ... }:
{
  flake.modules.nixos.server = {
    imports = [ config.flake.modules.nixos.ssh ];
    fleet.logging.persistent = true;
    # Minimal server profile: no default editor or administration workspace.
    programs.nano.enable = false;
    networking.nftables.enable = true;
    systemd.coredump.enable = false;
    # Conservative hardening, without a different kernel/profile that could
    # break ZFS, virtualization, hardware drivers or console recovery.
    boot.kernel.sysctl = {
      "kernel.kptr_restrict" = 2;
      "kernel.dmesg_restrict" = 1;
      "kernel.yama.ptrace_scope" = 1;
      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
    };
  };

  fleet.validation.hostChecks.serverBaseline =
    {
      name,
      host,
      system,
    }:
    let
      cfg = system.config;
      homePath =
        path:
        path == "/"
        || path == "/home"
        || lib.hasPrefix "/home/" path
        || path == "/root"
        || lib.hasPrefix "/root/" path;
      persisted = lib.concatMap (state: [ state ] ++ lib.attrValues state.users) (
        lib.attrValues cfg.environment.persistence
      );
      packages = map lib.getName cfg.environment.systemPackages;
    in
    assert lib.assertMsg
      (
        !(lib.elem name [
          "bastion"
          "racknerd"
        ])
        || (
          !(lib.any (capability: lib.elem capability host.capabilities) [
            "agents"
            "editors"
            "desktop"
          ])
          && !(cfg ? home-manager)
          && !cfg.programs.nano.enable
          && !cfg.programs.neovim.enable
          && lib.all (package: !(lib.elem package packages)) [
            "pi-coding-agent"
            "rtk"
            "cursor-cli"
            "gh"
            "git"
            "nodejs"
            "tmux"
            "devenv"
            "herdr"
            "neovim"
            "nano"
            "vim"
            "emacs"
          ]
          && cfg.fileSystems."/".fsType == "tmpfs"
          && cfg.users.users.marcos.home == "/home/marcos"
          && cfg.users.users.marcos.createHome
          && cfg.users.users.marcos.homeMode == "700"
          && !(lib.any homePath (lib.filter (path: path != "/") (lib.attrNames cfg.fileSystems)))
          && !(lib.any (mount: homePath mount.where) cfg.systemd.mounts)
          && lib.all (
            state:
            !(lib.any (d: homePath d.dirPath) state.directories)
            && !(lib.any (f: homePath f.filePath) state.files)
          ) persisted
          && !(lib.any (path: lib.hasPrefix "fleet-agents/" path) (lib.attrNames cfg.environment.etc))
          && !(cfg.environment.sessionVariables ? CURSOR_AGENT_PATH)
          && !(cfg.environment.sessionVariables ? RTK_TELEMETRY_DISABLED)
          && !(lib.any (rule: lib.hasInfix "/etc/fleet-agents" rule) cfg.systemd.user.tmpfiles.rules)
          && cfg.nix.settings.trusted-users == [ "root" ]
          && cfg.nix.settings.require-sigs
          && cfg.security.sudo.wheelNeedsPassword
          && !cfg.fleet.access.passwordlessSudo
          && !cfg.users.mutableUsers
        )
      )
      "${name}: minimal servers must have ephemeral homes, no editor/agent workspace and unchanged least-privilege access";
    true;
}
