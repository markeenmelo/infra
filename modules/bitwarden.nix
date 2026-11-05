let
  server = "https://vault.disroot.org";
  extension = "{446900e4-71c2-419f-a6a7-df9c091e268b}";
in
{
  flake.modules.darwin.desktop =
    { config, ... }:
    {
      system.defaults.CustomUserPreferences."app.zen-browser.zen" = {
        ExtensionSettings.${extension} = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          private_browsing = true;
        };
        "3rdparty".Extensions.${extension}.environment.base = "${server}/";
      };
      home-manager.users.${config.system.primaryUser} =
        { pkgs, ... }:
        {
          programs.rbw = {
            enable = true;
            settings = {
              email = "marcosmelo@proton.me";
              base_url = server;
              lock_timeout = 300;
              pinentry = pkgs.pinentry_mac;
            };
          };
          programs.zsh.initContent = ''
            [ -S ~/.bitwarden-ssh-agent.sock ] && export SSH_AUTH_SOCK=~/.bitwarden-ssh-agent.sock
          '';
        };
    };
}
