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
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          bw = lib.getExe pkgs.bitwarden-cli;
        in
        {
          home = {
            packages = [ pkgs.bitwarden-cli ];
            sessionVariables.SSH_AUTH_SOCK = "${config.home.homeDirectory}/.bitwarden-ssh-agent.sock";
            activation.bitwardenServer = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              [ "$(${bw} config server)" = ${server} ] || run ${bw} config server ${server}
            '';
          };
        };
    };
}
