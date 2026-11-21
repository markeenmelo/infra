{ fetchgit, stdenvNoCC }:
let
  plugins = [
    "github-prs"
    "tailnet"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "noctalia-plugins";
  version = "0-unstable-2026-11-20";
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins";
    rev = "546e0b72fda2bcb41a6bd07acfc41e37e4508eae";
    hash = "sha256-adPkXZXZhlJ1qrYNlZZpDj3/ucxL963ltwdnqX12rM8=";
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
