# Manual ciphertext preflight

The task implementations were removed on 2026-09-13. Retain these reviewed checks as manual skill instructions until a later task design is requested; no command wrapper or task is registered.

Run the complete first block from the repository root in a Bash inside the locked devenv shell, **before staging ciphertext/public rules or evaluating the flake**. It reads only ciphertext/public metadata, never identities or decrypted values. Stop on any failure. Nix copies tracked inputs into the public store before evaluation; flake checks cannot retroactively protect that copy. Review all other intended files separately for secrets.

The guard rejects multiple documents, duplicate/merge keys before JSON conversion, plaintext scalars, missing/invalid metadata, unsupported backends, recipient drift and extra shared-password keys. It does not prove a valid MAC, password hash, custody, recovery or runtime delivery.

```bash
set -euo pipefail
check_secret_payloads() {
  local rules file
  rules=$(yq -o=json '.' .sops.yaml 2>/dev/null) || {
    echo 'Cannot parse .sops.yaml (content withheld).' >&2
    return 1
  }
  shopt -s nullglob
  local -a files
  files=(secrets/hosts/*.yaml secrets/shared/*.yaml)
  if ((${#files[@]} == 0)); then
    echo 'No encrypted credential files found.' >&2
    return 1
  fi
  for file in "${files[@]}"; do
    # JSON conversion discards duplicate keys and overridden YAML merge values.
    # Reject both in the YAML tree before inspecting the converted payload.
    if ! yq -e '([.. | select(tag == "!!map") | keys | select(length != (unique | length))] + [... | select(tag == "!!merge")]) | length == 0' "$file" >/dev/null 2>&1; then
      printf 'Ambiguous or invalid YAML: %s (content withheld).\n' "$file" >&2
      return 1
    fi
    if ! yq -o=json '.' "$file" 2>/dev/null | jq -e -s --arg file "$file" --argjson rules "$rules" '
      def encrypted:
        type == "string" and test("^ENC\\[AES256_GCM,data:[A-Za-z0-9+/=]+,iv:[A-Za-z0-9+/=]+,tag:[A-Za-z0-9+/=]+,type:str\\]$");
      if length != 1 then error("Expected one YAML document") else .[0] end
      | . as $doc
      | [$rules.creation_rules[] | . as $rule | select($file | test($rule.path_regex))] as $matching
      | type == "object"
        and ($matching | length == 1)
        and ($matching[0].key_groups | length == 1)
        and ($matching[0].key_groups[0] | keys == ["age"])
        and (if $file == "secrets/shared/marcos-password.yaml"
             then (keys | sort) == ["marcos-password-hash", "sops"] else true end)
        and ([del(.sops) | .. | scalars] | length > 0 and all(.[]; encrypted))
        and (.sops.mac | encrypted)
        and (.sops.age | length > 0)
        and (all(.sops.age[];
          (keys | sort == ["enc", "recipient"])
          and (.recipient | test("^age1[a-z0-9]+$"))
          and (.enc | startswith("-----BEGIN AGE ENCRYPTED FILE-----") and contains("-----END AGE ENCRYPTED FILE-----"))))
        and (([.sops.age[].recipient] | sort) == ($matching[0].key_groups[0].age | sort))
        and (["kms", "gcp_kms", "azure_kv", "hc_vault", "pgp"] | all(.[]; ($doc.sops[.] // []) == []))
        and (.sops | keys - ["age", "mac", "version", "lastmodified", "unencrypted_suffix", "kms", "gcp_kms", "azure_kv", "hc_vault", "pgp"] | length == 0)
    ' >/dev/null 2>&1; then
      printf 'Encrypted payload/recipient check failed: %s (content withheld).\n' "$file" >&2
      return 1
    fi
  done
  printf 'Encrypted credential payloads and recipient rules checked (%s files); no decryption.\n' "${#files[@]}"
}
check_secret_payloads
```

## Regressions

In the same Bash (with `check_secret_payloads` still defined), run the whole block below. It mutates only disposable copies and obvious synthetic payloads; copied store inputs need writable test permissions. All eleven invalid variants must reject without printing their dummy values. No decryption or target operation occurs.

```bash
(
set -euo pipefail
declare -F check_secret_payloads >/dev/null
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
(cd "$work" && check_secret_payloads)
repo=$PWD
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
  if (cd "$work" && check_secret_payloads) >"$work/result" 2>&1; then
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
)
```
