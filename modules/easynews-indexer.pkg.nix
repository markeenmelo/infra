{
  fetchFromGitHub,
  python3,
  writeShellApplication,
}:
let
  version = "0-unstable-2026-05-10";
  src = fetchFromGitHub {
    owner = "Sanket9225";
    repo = "Easynews_as_indexer";
    rev = "35a8b8641ccd3375c2746a3c5e4145b6dabe3a0a";
    hash = "sha256-R1ah46gV7PAJBr/3D8AmqfHx0smEvpHRii9XcuGsEGQ=";
  };
  python = python3.withPackages (ps: [
    ps.flask
    ps.gunicorn
    ps.requests
  ]);
in
writeShellApplication {
  name = "easynews-indexer";
  passthru = { inherit version src; };
  text = ''exec ${python}/bin/gunicorn --chdir ${src} --no-control-socket "$@" server:APP'';
}
