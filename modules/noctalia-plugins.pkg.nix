{ fetchgit, stdenvNoCC }:
let
  plugins = [
    "claudecode"
    "github-prs"
    "meeting-bar"
    "tailnet"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "noctalia-plugins";
  version = "0-unstable-2026-11-15";
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins";
    rev = "9eb0fa03845a82b352d830c21f002048822d79e8";
    hash = "sha256-fa+ekCdBBXP7zCPfo/JUoXFpu6+ftBcGA7aV6AE5CAY=";
    sparseCheckout = map (plugin: "/${plugin}") plugins;
  };
  postPatch = ''
    substituteInPlace tailnet/bar.luau \
      --replace-fail '["running"] = "primary"' '["running"] = "on_surface"'
    substituteInPlace meeting-bar/widget.luau \
      --replace-fail 'barWidget.setColor(event and event.startMs <= now and "primary" or "on_surface")' 'barWidget.setColor("on_surface")'
  '';
  installPhase = ''
    mkdir "$out"
    cp -r ${toString plugins} "$out/"
  '';
}
