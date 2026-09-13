#!/usr/bin/env bash
set -euo pipefail
exec "${FLEET_REAL_SSH:?Missing locked SSH executable}" \
  -F /dev/null \
  -o StrictHostKeyChecking=yes \
  -o UpdateHostKeys=no \
  -o PermitLocalCommand=no \
  -o PreferredAuthentications=publickey \
  -o "UserKnownHostsFile=${FLEET_INSTALL_KNOWN_HOSTS:?Missing pinned installer identity}" \
  -o GlobalKnownHostsFile=/dev/null \
  -o HostKeyAlgorithms=ssh-ed25519 \
  -o BatchMode=yes \
  -o PasswordAuthentication=no \
  -o KbdInteractiveAuthentication=no \
  -o IdentitiesOnly=yes \
  -o IdentityAgent=none \
  -o ForwardAgent=no \
  -o ClearAllForwardings=yes \
  -o ConnectTimeout=15 \
  -o ServerAliveInterval=10 \
  -o ServerAliveCountMax=3 \
  -i "${FLEET_INSTALL_IDENTITY:?Missing reviewed installer login identity}" "$@"
