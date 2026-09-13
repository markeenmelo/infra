# Implementation rationale retained from code comments

These notes preserve non-obvious constraints after prose-comment removal on 2026-09-13. Read the owning implementation/check and dated research before changing behavior; the notes are not evidence of a new runtime test.

## Evaluation and tests

- Every discovered module is top-level. `/_` helpers are excluded by import-tree; Nix `//` is attribute merging, not a comment. No manual duplicate imports.
- SSH's stable module `key` prevents duplicate list contributions through server/deployment diamonds. Class wrappers alone do not give that anonymous value an identity.
- Desktop rejects the actual evaluator track through native `modulesPath` during import collection, avoiding config-dependent import recursion. Test the import graph positively and negatively; incomplete toplevels can fail for unrelated reasons and give vacuous rejection tests.
- Force assertion **booleans** in negative fixtures. Passing upstream assertions may have messages that throw when evaluated; the NixOS toplevel renders only failed messages.
- Synthetic fixture facts apply only to requested capabilities. Combined fixtures can hide missing exact-subset dependencies; independent inventories/track/rollout oracles must remain independent of production choices.
- `unsafeDiscardStringContext` is used only after forcing report metadata, so evaluation fixtures do not accidentally become huge system-build dependencies. Never discard secret or dependency contexts as a workaround.
- Native disko scripts are positive plan outputs; redirected VM/image aliases can legitimately fail access/device guards. All public aliases need negative coverage. Even an empty legacy script can unmount `/mnt`.

## Runtime policy

- Logging contributes to persistence. Probe `settings.Journal` availability, not channel names, for the stable `extraConfig` compatibility branch; remove it when both pins support settings. Normal-priority lines preserve storage policy when another feature adds journal tuning; `mkDefault` would lose the whole string.
- Do not import upstream headless profiles that remove consoles/emergency recovery. Headless means no desktop here.
- Limine contributes a wallpaper via `mkDefault` after its empty option default, so the explicit empty wallpaper list is intentional. Read effective values, not only option defaults. Each layout explicitly disables otherwise-default LVM.
- SOPS identities are direct early `/persist` string paths, not late binds or Nix paths. The explicit empty age SSH-key import prevents upstream coupling to the ED25519 host identity. Adding RSA keys must not silently enable GPG imports. Missing identity/recipient withholds declaration and locks only the candidate account.
- Impermanence does not repair existing backing modes. AccountsService also re-enforces upstream 0775 on service start; its private-mode override is separately necessary. Removing a bind does not erase backing data.
- See [desktop policy](../../desktop/SKILL.md) for password-first fingerprint/PAM, GUI submission versus authentication, safe display IPC, Wi-Fi escaping, manual CUPS queries, browser pin behavior and shell ordering.
- See [Tailscale](../../tailscale/SKILL.md) for bare reconnect, file-reference auth, sanitized diagnostics, real-daemon boundaries, isolated OpenTofu workspaces/providers and encrypted emergency-state recovery.

## Test asset boundaries

Python test module descriptions previously identified synthetic data: display tests use mocked hardware/commands and disposable sockets (native socat only there); printer tests replace only executable boundaries and never contact CUPS/printers; Wi-Fi tests use synthetic scalars/real escaping; Tailscale reconciliation/provider/SOPS tests mock all real credential/API boundaries. The offline encryption fixture alone applies temporary local `terraform_data` state. Pi loader tests use empty HOME/no provider and call the actual packaged retry classifier, not a copied prefix regex. Native binaries may emit version/help on stderr; capture it and still require exact expected values.

Shebangs, licenses/tool directives and comment-looking **data** (Nix/jq operators, URLs, hashes, test scalars) must remain intact during cleanup. Option descriptions and refusal/assertion messages are executable metadata, not prose comments to strip.
