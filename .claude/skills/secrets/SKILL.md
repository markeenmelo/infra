---
name: secrets
description: "SOPS and sops-nix: which file and recipients hold a key, how a unit receives a secret, adding a host or rotating a key, the secrets check. Use before touching secrets/, .sops.yaml, sops.secrets or any credential, and when asked where a credential lives."
---

# Secrets

Only ciphertext enters Git; `.sops.yaml` owns the recipients, one exact rule per file. Claude
never decrypts or edits a secret: it names the file, key and command and the operator runs it in a
private terminal ([CLAUDE.md](../../../CLAUDE.md#autonomy)).

**Never** paste a decrypted or generated value into chat, a command argument or Nix; commit editor
backups of decrypted files; or add a plaintext placeholder to make a build pass. Removing
ciphertext or a recipient revokes nothing already in Git history: a lost or exposed identity means
rotating every value its files held.

## Identities

- **Operator**: the age key in `~/.config/sops/age/keys.txt` (`&operator`).
- **Hosts**: derived from the SSH host key, `ssh-to-age <<< "$(cat /etc/ssh/ssh_host_ed25519_key.pub)"`.
  [secrets.nix](../../../modules/secrets.nix) reads `/persist/etc/ssh/ssh_host_ed25519_key`
  directly, since activation decrypts before tmpfiles links `/etc/ssh`. A reinstall keeps the key by
  passing the preserved `/persist/etc/ssh` to nixos-anywhere `--extra-files`; a new key is a new
  recipient and `sops updatekeys` on every file whose rule names the host.

## Files

| File | Recipients | Keys |
|---|---|---|
| `shared/login.yaml` | operator, every host | `marcos-password-hash` ([access.nix](../../../modules/access.nix)) |
| `hosts/HOST.yaml` | operator, HOST | `tailscale-auth-key` ([tailnet skill](../tailnet/SKILL.md)) |
| `tailscale/operator.yaml` | operator | Tailscale OAuth client, tailnet name, state passphrase ([opentofu skill](../opentofu/SKILL.md)) |
| `porkbun/api.yaml` | operator, racknerd | `PORKBUN_API_KEY`, `PORKBUN_SECRET_KEY` for DNS-01 ([proxy skill](../proxy/SKILL.md)) |

## Delivery

Declare `sops.secrets.NAME` beside its consumer with `sopsFile`, `key` when the SOPS path differs,
`neededForUsers` for a password hash and `restartUnits` for every reader. Delivery is root-owned
0400 (asserted in [secrets.nix](../../../modules/secrets.nix)); a unit reads through
`LoadCredential` or the upstream module's `*File` option. A unit that needs a file in its own
format gets a `sops.templates` entry rendered from `sops.placeholder`, so the secrets it
references stay declared; the template is delivered the same way.

## Editing

```sh
sops edit secrets/shared/login.yaml        # change values; keep keys and recipients
sops updatekeys -y secrets/shared/login.yaml  # after a .sops.yaml rule change
```

Ciphertext edit and consumer declaration land in the same commit. The `secrets` check fails on a
non-sops file under `secrets/`, a plaintext value inside one, and secret material anywhere in the tree.

## New host

1. Operator shares the host's age recipient (above).
2. Add the anchor and an exact `hosts/HOST.yaml` rule to `.sops.yaml`; add the host to each shared
   rule whose file it reads.
3. Operator runs `sops updatekeys -y` on those shared files and `sops edit` for the host file.
