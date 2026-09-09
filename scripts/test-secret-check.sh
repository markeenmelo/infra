#!/usr/bin/env bash
set -euo pipefail

# Local throwaway ciphertext copies + obvious dummy strings, never decryption.
repo=$PWD
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/secrets/hosts"
cp .sops.yaml "$work/.sops.yaml"
file="$work/secrets/hosts/thinkpad.yaml"
cp secrets/hosts/thinkpad.yaml "$file"
# Store inputs are read-only; only this disposable test copy may be mutated.
chmod u+w "$file"
(cd "$work" && bash "$repo/scripts/check-secrets.sh")

for variant in plaintext recipient missing-mac unsupported-backend invalid-yaml multiple-documents duplicate-key; do
  cp "$repo/secrets/hosts/thinkpad.yaml" "$file"
  case "$variant" in
    plaintext) yq -i '."marcos-password-hash" = "TEST-ONLY-NOT-A-HASH"' "$file" ;;
    recipient) yq -i '.sops.age[0].recipient = .sops.age[1].recipient' "$file" ;;
    missing-mac) yq -i 'del(.sops.mac)' "$file" ;;
    unsupported-backend) yq -i '.sops.kms = [{"arn": "TEST-ONLY-NOT-A-KEY"}]' "$file" ;;
    invalid-yaml) printf 'unclosed: [\n' > "$file" ;;
    multiple-documents)
      {
        printf 'plain: TEST-ONLY-NOT-A-SECRET\n---\n'
        dd if="$repo/secrets/hosts/thinkpad.yaml" status=none
      } > "$file"
      ;;
    duplicate-key)
      {
        printf 'marcos-password-hash: TEST-ONLY-NOT-A-HASH\n'
        dd if="$repo/secrets/hosts/thinkpad.yaml" status=none
      } > "$file"
      ;;
  esac
  if (cd "$work" && bash "$repo/scripts/check-secrets.sh") >"$work/result" 2>&1; then
    printf 'ERROR: secret guard accepted %s.\n' "$variant" >&2
    exit 1
  fi
  grep -q 'content withheld' "$work/result"
  if grep -q 'TEST-ONLY-NOT-' "$work/result"; then
    printf 'ERROR: secret guard printed dummy payload for %s.\n' "$variant" >&2
    exit 1
  fi
  printf 'Secret guard rejected %s; values withheld.\n' "$variant"
done
