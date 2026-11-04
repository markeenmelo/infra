{ inputs, ... }:
{
  flake.modules.darwin.desktop =
    { config, lib, ... }:
    {
      imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];
      nix-homebrew = {
        enable = true;
        user = config.system.primaryUser;
        mutableTaps = false;
        taps = {
          "homebrew/homebrew-core" = inputs.homebrew-core;
          "homebrew/homebrew-cask" = inputs.homebrew-cask;
        };
      };
      homebrew = {
        enable = true;
        taps = lib.attrNames config.nix-homebrew.taps;
        global.autoUpdate = false;
        onActivation.cleanup = "zap";
        casks = [
          "zen"
          "ghostty"
          "zed"
          "bitwarden"
          "whatsapp"
          "telegram"
          "spotify"
          "bruno"
          "steam"
          "betterdisplay"
        ];
      };
    };
}
