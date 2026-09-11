{
  # Bitwarden desktop/CLI and its SSH agent. Vault data, the unlock state and
  # Bitwarden's own autostart entry stay mutable application state: nothing here
  # reads, imports or removes them.
  flake.modules.nixos.desktop = {
    # GNOME Keyring keeps providing Secret Service storage for desktop clients,
    # but its SSH agent would race Bitwarden's for signing requests.
    services.gnome.gcr-ssh-agent.enable = false;
  };

  flake.modules.homeManager.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      agentSocket = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
      exportSocket = "export SSH_AUTH_SOCK=${lib.escapeShellArg agentSocket}";
    in
    {
      home.packages = [
        pkgs.bitwarden-cli
        pkgs.bitwarden-desktop
      ];

      # Bitwarden owns the agent process itself. This only points local clients
      # at its documented native socket, and the upstream module keeps a
      # forwarded agent from an inbound SSH session intact.
      sshAuthSock = {
        enable = true;
        initialization = {
          bash = exportSocket;
          zsh = exportSocket;
          fish = "set -x SSH_AUTH_SOCK ${lib.escapeShellArg agentSocket}";
          nushell = "$env.SSH_AUTH_SOCK = '${agentSocket}'";
        };
        # Ordering only: the unit is generated from Bitwarden's own autostart
        # entry, which this module neither creates nor deletes.
        systemd.socketProviderUnit = "app-bitwarden@autostart.service";
      };
    };
}
