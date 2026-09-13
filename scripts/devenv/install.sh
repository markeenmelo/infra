#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 1 || ! $1 =~ ^[a-z][a-z0-9-]*$ ]]; then
  exec @coreutilsInstall@ "$@"
fi
if [[ $- == *x* ]]; then set +x; echo 'Refusing guided installation with shell tracing.' >&2; exit 1; fi
cd "${DEVENV_ROOT:?Enter the locked devenv shell}"
exec python3 scripts/storage/install-guide.py "$1"
