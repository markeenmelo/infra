{
  flake.modules.homeManager.desktop =
    {
      lib,
      pkgs,
      ...
    }:
    {
      xdg.terminal-exec = {
        enable = true;
        settings.default = [ "com.mitchellh.ghostty.desktop" ];
      };

      programs = {
        ghostty = {
          enable = true;
          settings.command = "direct:${lib.getExe pkgs.herdr}";
        };

        herdr = {
          enable = true;
          settings = {
            keys.prefix = "ctrl+a";
            onboarding = false;
            terminal.default_shell = lib.getExe pkgs.zsh;
            update = {
              manifest_check = true;
              version_check = false;
            };
            ui.toast.delivery = "herdr";
            session.resume_agents_on_restore = true;
            experimental.pane_history = false;
          };
        };
      };
    };
}
