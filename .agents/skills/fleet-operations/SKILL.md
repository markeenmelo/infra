---
name: fleet-operations
description: Consult and maintain dated fleet hardware, credential, installation and boot evidence without confusing candidate readiness with runtime acceptance or authorization.
---

# Fleet operations and evidence

Read `../../../AGENTS.md` and [authoritative current status](references/hosts.md#current-status) before any host decision. The reference retains dated observations and exact acceptance evidence from the former host runbook; historical commands and permissions are not current instructions.

## Procedure

1. Identify the target, requested operation and exact candidate. Compare `modules/hosts/<host>/host.nix` with dated evidence; do not refresh facts through remote contact without authorization.
2. Keep candidate readiness, installed generation, credential acceptance, two-boot acceptance and deployment permission separate. Both servers' fresh installs/two boots are accepted as of 2026-09-13; the later minimal-server/two-key candidate remains unactivated. ThinkPad's fresh plain candidate remains unready/local-only despite historical encrypted-installation acceptance.
3. Keep the operator-selected MacBook/controller and independent credentials/recovery outside ThinkPad's future wipe. Controller readiness is operator-reported; this repository exports only `x86_64-linux` tooling. Do not create a server workspace or broaden Nix trust to bypass that constraint.
4. For local inspection, first follow the ciphertext preflight in [validate](../validate/SKILL.md), then inspect `nix eval --no-update-lock-file --json .#fleet` and the deployment/Tailscale plans as needed. Evaluation authorizes no target contact.
5. Use [storage-disko](../storage-disko/SKILL.md) for new installations, [impermanence](../impermanence/SKILL.md) for state, [deploy](../deploy/SKILL.md) for activation/recovery and [tailscale](../tailscale/SKILL.md) for enrollment/policy. Preserve Bastion's eight legacy NAS mounts outside OS disko.
6. Record new evidence with date, revision, exact scope, source (observed or operator-reported), failures and remaining unknowns. Update current status without rewriting historical results or copying review flags between candidates.

## Completion

Status links and acceptance claims agree; historical approvals are not represented as permission for a new operation. No secret values or private identities are collected just to record review.
