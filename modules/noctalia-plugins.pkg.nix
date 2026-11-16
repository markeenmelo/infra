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
  version = "0-unstable-2026-11-16";
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins";
    rev = "5413d9c1a390c9c5900c836f482d45d108840b80";
    hash = "sha256-Zxg3ARcSchCNmdnXdqnbfyVtIpTqf3+RkhjWuQFPk4o=";
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
