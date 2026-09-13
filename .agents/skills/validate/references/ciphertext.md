# Ciphertext preflight

The explicitly requested operator-task design restores the reviewed guard as `scripts/secrets/check.sh` and its eleven disposable regressions as `scripts/secrets/test-check.sh`. The earlier task removal is historical; there is still no secret loading at shell entry.

Before staging ciphertext/public rules or evaluating a Git flake, run from the repository root with the locked `yq` and `jq` tools:

```bash
bash scripts/secrets/check.sh
```

This must precede any bootstrap command that copies the repository into the Nix store. A later flake check cannot retroactively protect that copy. Review other intended files separately and never stage private identities, plaintext credentials or unrelated work.

The guard rejects multiple documents, duplicate/merge keys before JSON conversion, plaintext scalars, missing/invalid SOPS metadata, unsupported backends, recipient drift and extra shared-password keys. It emits filenames/status only, withholding contents. It does not decrypt or prove a valid MAC, password, identity custody, recovery or runtime delivery.

## Regressions

```bash
bash scripts/secrets/test-check.sh
```

Only disposable copies are made writable and mutated. Plaintext, recipient, missing-MAC, unsupported-backend, malformed-YAML, multiple-document, duplicate-key, merge-key, nested-merge, shared-plaintext and shared-extra-key variants must all reject without exposing their synthetic markers. No real ciphertext, credentials or target state is changed.

The operator preflight and source-quality check run these regressions. Full [validation](../SKILL.md) remains required; a passing structural guard is not commissioning or operation authorization.
