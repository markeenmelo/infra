#!/usr/bin/env bash
exec python3 "$DEVENV_ROOT/scripts/tailscale/tailscale-sops.py" "$@"
