{
  src,
  python3,
  writeShellApplication,
}:
let
  python = python3.withPackages (ps: [
    ps.flask
    ps.gunicorn
    ps.requests
  ]);
in
writeShellApplication {
  name = "easynews-indexer";
  text = ''exec ${python}/bin/gunicorn --chdir ${src} --no-control-socket "$@" server:APP'';
}
