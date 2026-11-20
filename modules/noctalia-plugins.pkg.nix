{ fetchgit, stdenvNoCC }:
let
  plugins = [
    "github-prs"
    "tailnet"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "noctalia-plugins";
  version = "0-unstable-2026-11-19";
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins";
    rev = "bccbc7f0f0c888814e506aa0ce48cbc8d90c91f0";
    hash = "sha256-G/fzi7vfHwwOu/lXa0DZh+5MLxmLMJTywkmiTBsHNw8=";
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
