{
  fetchFromGitHub,
  python3,
  writeShellApplication,
}:
let
  version = "2.2.0";
  src = fetchFromGitHub {
    owner = "ManiMatter";
    repo = "decluttarr";
    tag = "v${version}";
    hash = "sha256-36XOEnNE5aJg9QkVK2nI8xK3RiugNH3Xjhswt3dhj+s=";
  };
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
