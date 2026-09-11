#!/usr/bin/env bash
set -euo pipefail

# Local throwaway ciphertext copies + obvious dummy strings, never decryption.
repo=$PWD
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/secrets/hosts" "$work/secrets/shared"
cp .sops.yaml "$work/.sops.yaml"
file="$work/secrets/hosts/thinkpad.yaml"
cp secrets/hosts/thinkpad.yaml "$file"
shared="$work/secrets/shared/marcos-password.yaml"
cp secrets/shared/marcos-password.yaml "$shared"
# Store inputs are read-only; only these disposable test copies may be mutated.
chmod u+w "$file" "$shared"
(cd "$work" && bash "$repo/modules/secrets/check-secrets.sh")

for variant in plaintext recipient missing-mac unsupported-backend invalid-yaml multiple-documents duplicate-key merge-key nested-merge \
  shared-plaintext shared-extra-key; do
  cp "$repo/secrets/hosts/thinkpad.yaml" "$file"
  cp "$repo/secrets/shared/marcos-password.yaml" "$shared"
  case "$variant" in
    plaintext) yq -i '."marcos-password-hash" = "TEST-ONLY-NOT-A-HASH"' "$file" ;;
    recipient) yq -i '.sops.age[0].recipient = .sops.age[1].recipient' "$file" ;;
    missing-mac) yq -i 'del(.sops.mac)' "$file" ;;
    unsupported-backend) yq -i '.sops.kms = [{"arn": "TEST-ONLY-NOT-A-KEY"}]' "$file" ;;
    invalid-yaml) printf 'unclosed: [\n' > "$file" ;;
    shared-plaintext) yq -i '."marcos-password-hash" = "TEST-ONLY-NOT-A-HASH"' "$shared" ;;
    shared-extra-key) yq -i '."wifi-psk" = ."marcos-password-hash"' "$shared" ;;
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
    merge-key)
      {
        printf '<<: {marcos-password-hash: TEST-ONLY-NOT-A-HASH}\n'
        dd if="$repo/secrets/hosts/thinkpad.yaml" status=none
      } > "$file"
      ;;
    nested-merge)
      # A nested merge's plaintext MAC would disappear during JSON conversion.
      awk '{ print } /^sops:$/ { print "    <<: {mac: TEST-ONLY-NOT-A-SECRET}" }' \
        "$repo/secrets/hosts/thinkpad.yaml" > "$file"
      ;;
  esac
  if (cd "$work" && bash "$repo/modules/secrets/check-secrets.sh") >"$work/result" 2>&1; then
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
