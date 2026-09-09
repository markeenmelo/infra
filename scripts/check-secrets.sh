#!/usr/bin/env bash
set -euo pipefail

# Ciphertext/public metadata only. Never decrypt, import identities or print values.
# This catches accidental plaintext and recipient drift, not cryptographic validity.
rules=$(yq -o=json '.' .sops.yaml 2>/dev/null) || {
  echo 'Cannot parse .sops.yaml (content withheld).' >&2
  exit 1
}
shopt -s nullglob
files=(secrets/hosts/*.yaml)
if ((${#files[@]} == 0)); then
  echo 'No encrypted host files found.' >&2
  exit 1
fi
for file in "${files[@]}"; do
  # JSON decoding otherwise keeps only the last value of a duplicate YAML key.
  if ! yq -e '[.. | select(tag == "!!map") | keys | select(length != (unique | length))] | length == 0' "$file" >/dev/null 2>&1; then
    printf 'Ambiguous or invalid YAML: %s (content withheld).\n' "$file" >&2
    exit 1
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
    exit 1
  fi
done
printf 'Encrypted host payloads and recipient rules checked (%s files); no decryption.\n' "${#files[@]}"
