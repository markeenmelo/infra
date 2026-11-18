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
  version = "0-unstable-2026-11-18";
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins";
    rev = "ec07fbdab6197127ef3541962baab60762b1a620";
    hash = "sha256-FkChPrCV7hGNEpR3E9u6/3Ps5xBKG65lKauUc6xY0ew=";
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
