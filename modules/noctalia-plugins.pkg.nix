{ fetchgit, stdenvNoCC }:
let
  plugins = [
    "androidconnect"
    "claudecode"
    "github-prs"
    "tailnet"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "noctalia-plugins";
  version = "0-unstable-2026-11-16";
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins";
    rev = "6036d2d668d5b43c9f1121256935aa86fda1929b";
    hash = "sha256-sqM2DcjRKOpcBZsk6j8wHtwKmhiZw0+QJySMxXVUv1o=";
    sparseCheckout = map (plugin: "/${plugin}") plugins;
  };
  postPatch = ''
    substituteInPlace tailnet/bar.luau \
      --replace-fail '["running"] = "primary"' '["running"] = "on_surface"'
  '';
  installPhase = ''
    mkdir "$out"
    cp -r ${toString plugins} "$out/"
  '';
}
