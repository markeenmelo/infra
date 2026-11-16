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
    rev = "1970ee8bb43ae98db854fa8516e38694d7c56be3";
    hash = "sha256-NvnIgIGuqfpJk8d4rQ3kP3J8Tyjx8ZIjSwfzO0t9mjw=";
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
