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
    rev = "49006a8bef2c43f08b93ba108618d8bf3cddca79";
    hash = "sha256-uXcVvkMJUYb0DTosoVXInbsmuX2Vq/0jhk5G+C9/mOE=";
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
