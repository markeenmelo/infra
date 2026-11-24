{ fetchgit, stdenvNoCC }:
let
  plugins = [
    "tailnet"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "noctalia-plugins";
  version = "0-unstable-2026-11-23";
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins";
    rev = "5efc3bbca3a98015822776db20a5138454022cec";
    hash = "sha256-P1XoAElLhwex83pMarvlFTN4ALTWWKym/hZhqMzOP4M=";
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
