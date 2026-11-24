{
  fetchFromGitHub,
  fetchPypi,
  lib,
  python3,
  writeShellApplication,
}:
let
  version = "0-unstable-2026-11-21";
  src = fetchFromGitHub {
    owner = "markeenmelo";
    repo = "Cthulu-Dice-Roller";
    rev = "970ffcce274857e73743710d7d3ebdc966152c3e";
    hash = "sha256-TjWlhQXNXyRk+u89kdUZGn8zsVIHZH8c0YQPtYhP+lI=";
  };
  py-cord = python3.pkgs.buildPythonPackage rec {
    pname = "py-cord";
    version = "2.8.1";
    pyproject = true;

    src = fetchPypi {
      pname = "py_cord";
      inherit version;
      hash = "sha256-sevSJBaUG77MttJt9cvWX/ax1H/LvJZS764DnkbopWI=";
    };

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail 'setuptools>=77.0.3,<=80.9.0' 'setuptools>=77.0.3' \
        --replace-fail 'setuptools-scm>=9.2,<=9.2.2' 'setuptools-scm>=9.2'
    '';

    build-system = with python3.pkgs; [
      setuptools
      setuptools-scm
    ];

    dependencies = with python3.pkgs; [
      aiohttp
      typing-extensions
    ];

    env.SETUPTOOLS_SCM_PRETEND_VERSION = version;

    doCheck = false;

    pythonImportsCheck = [
      "discord"
      "discord.commands"
    ];

    meta = {
      description = "Python wrapper for the Discord API (Pycord)";
      homepage = "https://pycord.dev";
      license = lib.licenses.mit;
    };
  };
  python = python3.withPackages (_: [ py-cord ]);
in
writeShellApplication {
  name = "dorian";
  passthru = { inherit version src; };
  text = ''exec ${python}/bin/python ${src}/dorian.py "$@"'';
}
