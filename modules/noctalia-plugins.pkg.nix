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
  version = "0-unstable-2026-11-17";
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins";
    rev = "0e90c16ac5ae80ebc64ff8575b116271343d35f0";
    hash = "sha256-WmYM/jhuR0wnPvCwSLBVAT10vFXJfLO57KjKGVX1eLg=";
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
