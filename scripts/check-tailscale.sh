#!/usr/bin/env bash
# Offline-only: mocked tailnet provider and a temporary built-in terraform_data
# resource. The only apply writes synthetic local state; no fleet/cloud target.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
python3 "$root/modules/tailscale/test-policy.py" "$root/tofu/tailscale/policy.hujson"
tofu -chdir="$root/tofu/tailscale" fmt -check -recursive
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
cp -R "$root/tofu/tailscale" "$scratch/config"
chmod -R u+w "$scratch/config"
mkdir -p "$scratch/home" "$scratch/state" "$scratch/smoke-state" "$scratch/smoke"
cp "$root/tofu/tailscale/encryption.tf" "$scratch/smoke/"
# This file is an explicitly synthetic, local-only encryption fixture.
printf '%s\n' 'resource "terraform_data" "canary" { input = "TEST-ONLY-ENCRYPTION-CANARY" }' > "$scratch/smoke/main.tf"
env -i PATH="$PATH" HOME="$scratch/home" SCRATCH="$scratch" \
  HTTP_PROXY=http://127.0.0.1:1 HTTPS_PROXY=http://127.0.0.1:1 NO_PROXY='' \
  TF_VAR_state_passphrase='TEST-ONLY-PASSPHRASE-NO-REAL-CREDENTIAL-0123456789' \
  TF_VAR_state_directory="$scratch/state" \
  TF_IN_AUTOMATION=1 bash <<'CHECK'
set -euo pipefail
cd "$SCRATCH/config"
tofu init -backend=false -input=false -lockfile=readonly
tofu validate
tofu test

cd "$SCRATCH/smoke"
export TF_VAR_state_directory="$SCRATCH/smoke-state"
tofu init -input=false
tofu plan -input=false -out="$SCRATCH/smoke-state/change.tfplan"
tofu apply -input=false "$SCRATCH/smoke-state/change.tfplan"
for file in "$SCRATCH/smoke-state/terraform.tfstate" "$SCRATCH/smoke-state/change.tfplan"; do
  jq -e '.encryption_version != null and (.encrypted_data | type == "string" and length > 0)' "$file" >/dev/null
  if grep -q 'TEST-ONLY-ENCRYPTION-CANARY\|TEST-ONLY-PASSPHRASE' "$file"; then
    printf 'Synthetic payload/passphrase leaked into encrypted file.\n' >&2
    exit 1
  fi
done
if TF_VAR_state_passphrase='TEST-ONLY-WRONG-PASSPHRASE-0123456789012345' tofu plan -input=false > "$SCRATCH/wrong-key.log" 2>&1; then
  printf 'Wrong encryption key unexpectedly accepted.\n' >&2; exit 1
fi
grep -Eqi 'decrypt|cipher|authentication failed' "$SCRATCH/wrong-key.log"
# Decrypt only this synthetic state to test fail-closed plaintext rejection.
tofu state pull > "$SCRATCH/plaintext-fixture"
cp "$SCRATCH/plaintext-fixture" "$SCRATCH/smoke-state/terraform.tfstate"
if tofu plan -input=false > "$SCRATCH/plaintext.log" 2>&1; then
  printf 'Plaintext state unexpectedly accepted.\n' >&2; exit 1
fi
grep -Eqi 'unencrypted|unenforce|encryption' "$SCRATCH/plaintext.log"
printf 'Native offline schema/mock plans and encrypted state/plan rejection tests passed.\n'
CHECK
