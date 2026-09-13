{
  flake.modules.nixos.desktop = {
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

      sshAuthSock = {
        enable = true;
        initialization = {
          bash = exportSocket;
          zsh = exportSocket;
          fish = "set -x SSH_AUTH_SOCK ${lib.escapeShellArg agentSocket}";
          nushell = "$env.SSH_AUTH_SOCK = '${agentSocket}'";
        };
        systemd.socketProviderUnit = "app-bitwarden@autostart.service";
      };
    };
}
