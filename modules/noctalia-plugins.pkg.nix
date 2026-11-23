{ fetchgit, stdenvNoCC }:
let
  plugins = [
    "github-prs"
    "tailnet"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "noctalia-plugins";
  version = "0-unstable-2026-11-23";
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins";
    rev = "7ae1a30ba157c84aab3750c2860b5f3675eb9bb8";
    hash = "sha256-82oKxgtRCxe/onUF1uUY6EHD4jc2ffRp3ozEQws9fSc=";
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
