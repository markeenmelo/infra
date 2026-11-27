{ fetchgit, stdenvNoCC }:
let
  plugins = [
    "tailnet"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "noctalia-plugins";
  version = "0-unstable-2026-11-27";
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins";
    rev = "e9d05419fda0bcc6a83a7f41a3b4b05f8d997e71";
    hash = "sha256-TCGXqkWWy2BtjtYX4aAnCuSTj3FNFB0sThe/7as0nVw=";
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
