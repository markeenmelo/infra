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
    rev = "133a2dfe9ffc30ec8b3b43d4cac2d0cb26ac4ced";
    hash = "sha256-LYacTs3x6ilynZyu6p+wjniiWo9iCBC9sDOKc1YMwhM=";
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
