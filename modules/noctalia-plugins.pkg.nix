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
    rev = "60332e1c43af22086c855fe3c3cbfbd35666cb90";
    hash = "sha256-XRH/zIvDrK4sP/lTIUiozqNSSZ84Liiln/P3csyzE8g=";
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
