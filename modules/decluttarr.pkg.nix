{
  src,
  python3,
  writeShellApplication,
}:
let
  python = python3.withPackages (ps: [
    ps.demjson3
    ps.packaging
    ps.python-dateutil
    ps.pyyaml
    ps.pyyaml-env-tag
    ps.requests
    ps.watchdog
  ]);
in
writeShellApplication {
  name = "decluttarr";
  text = ''exec ${python}/bin/python ${src}/main.py "$@"'';
}
