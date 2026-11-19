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
    rev = "b9aefd48419862beb576ac9dbb6ff065c5d37c60";
    hash = "sha256-IvBQ0kYD7JNCX3+a3YBKfS7FCYGtfHouujYqQ7nqu5E=";
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
