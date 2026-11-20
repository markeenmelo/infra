let
  server = "https://vault.disroot.org";
  extension = "{446900e4-71c2-419f-a6a7-df9c091e268b}";
  zen = {
    ExtensionSettings.${extension} = {
      installation_mode = "force_installed";
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
      private_browsing = true;
      default_area = "navbar";
    };
    "3rdparty".Extensions.${extension}.environment.base = "${server}/";
  };
in
{
  flake.modules.nixos.desktop.services.gnome.gcr-ssh-agent.enable = false;

  flake.modules.homeManager.desktop =
    { config, pkgs, ... }:
    {
      home = {
        packages = [ pkgs.bitwarden-desktop ];
        sessionVariables.SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
      };
      programs.zen-browser.policies = zen;
      xdg.autostart = {
        enable = true;
        entries = [ "${pkgs.bitwarden-desktop}/share/applications/bitwarden.desktop" ];
      };
    };
}
