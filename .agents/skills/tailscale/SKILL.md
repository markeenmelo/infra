---
name: tailscale
description: Staged Tailscale clients and the OpenTofu-managed tailnet policy, encrypted state and operator credentials. Use for client rollout, policy changes, provider or state maintenance, and enrollment planning.
---

# Tailscale and OpenTofu

Clients live in `modules/tailscale/`, the tailnet policy in `tofu/tailscale/`. Keep three things separate: local configuration and tests, live policy management, and host enrollment. None of them authorizes the next.

## Policy

`tofu/tailscale/policy.hujson` is applied through `tailscale_acl`, which **replaces the tailnet's entire policy file** — including any personal or family rules that are not in this repository. Export and review the current policy privately before the first apply of a change, and keep one writer: disable other GitOps publishers, and reconcile any emergency console edit back into Git before the next apply.

The fleet grant is deliberately narrow: ThinkPad's tag to the two server tags, TCP 22 and ICMP; everything else is denied. Replies are stateful, the reverse direction is not granted. This is ordinary OpenSSH over the tailnet, not Tailscale SSH, and it never changes public or LAN firewall policy — that stays as independent recovery.

A tag is a role, not a hardware fingerprint and not a uniqueness constraint. Assign each fleet tag to exactly one intended device, verify cardinality in the admin console before applying or enrolling, and revoke an obsolete node before reusing its tag. Tagged nodes replace user ownership, which changes device-key expiry — decide that deliberately.

MagicDNS is managed through `tailscale_dns_preferences`; resolvers and search domains are not. Auth keys, OAuth clients and subnet routes are deliberately outside this configuration.

## Provider and state

The shell pins OpenTofu and a Nix-built Tailscale provider, used offline. `init` reports that mirrored provider as **unauthenticated** because it is not an upstream signed release archive — that is expected; trust comes from the pinned source and build. Do not swap in a registry binary. A nixpkgs update can change the mirror checksum without a provider version change: compare the derivations and wrappers before touching `.terraform.lock.hcl`, and never regenerate it to silence a mismatch.

State stays private, encrypted and outside Git and the Nix store, with its existing passphrase. Never recreate state, rotate the passphrase, repeat a completed import, add a plaintext fallback or enable debug logging. OpenTofu rejects a saved plan from a different CLI version — get a fresh reviewed plan rather than working around it.

## Credentials and live operations

Credentials belong only to a private runtime process:

```sh
devenv shell tailnet-sops ENCRYPTED.yaml OPERATION
```

The adapter decrypts exactly the OAuth client ID, secret and state passphrase into the child process. No task, shell hook or Nix evaluation may decrypt anything. Use read-only API scopes for review; a write client is a separate, separately authorized credential.

`tailnet verify` saves no plan but **still contacts the API** — exit 0 means no changes, 2 drift, 1 error. Plan, apply and enrollment each need their own current authorization.

## Clients

Roll out one host at a time. A disabled host keeps its backing state without an active daemon; disabling is not revocation. Enrollment uses a single-use auth key delivered by a declared SOPS secret, referenced by file and only while the daemon reports `NeedsLogin`. Reconnect a stopped identity with a plain `up`, never a forced reset that loses preferences, and never let manual enrollment race the reconciler.

Checks are offline and mocked: they prove no decryption, enrollment, policy application, traffic or restore.
