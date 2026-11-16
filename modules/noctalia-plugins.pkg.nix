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
    rev = "29a0756b71f19a38ace074d195be3a14cd6700f6";
    hash = "sha256-Nr10O7UGCj+DLf8lLGyStZqn12rtJbuBzpijeQqLZ7A=";
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
