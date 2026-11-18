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
    rev = "744fe5a1909ff5ebc1da3f74b1ffbf59668b9b9c";
    hash = "sha256-q8SRcZ/dj0OCkGnzQnp2Nnvcvewl5ZQeBlZT2mKfAL0=";
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
