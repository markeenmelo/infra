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
  version = "0-unstable-2026-11-12";
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins";
    rev = "33d7ba696a6644016ae3c0706c0b5fcf066e42e8";
    hash = "sha256-zZzil9RDGdZY18l+yX18k2Nbd0MQQ1G+iuBxlE5S/Hs=";
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
