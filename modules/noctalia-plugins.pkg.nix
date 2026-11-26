{ fetchgit, stdenvNoCC }:
let
  plugins = [
    "tailnet"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "noctalia-plugins";
  version = "0-unstable-2026-11-25";
  src = fetchgit {
    url = "https://github.com/noctalia-dev/community-plugins";
    rev = "f428ba308165179ee5c835f6ee56a770911f5fa4";
    hash = "sha256-Fc2r1WgMAAKYxKp7gv8XpdXFzjlbI7vfxHDQYgNEzBo=";
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
