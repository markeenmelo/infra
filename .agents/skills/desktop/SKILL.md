---
name: desktop
description: Maintain ThinkPad desktop, authentication, display, Wi-Fi and agent configuration with native modules, private state and explicit runtime acceptance boundaries.
---

# ThinkPad desktop

Read `../../../AGENTS.md`, [dendritic-nix](../dendritic-nix/SKILL.md), [desktop ownership and acceptance](references/desktop.md), [Pi policy](references/pi.md) when relevant, and [current host status](../fleet-operations/references/hosts.md#current-status). Retained [ADR 0008](../dendritic-nix/references/adr/0008-native-desktop-and-kernels.md) records the design.

## Procedure

1. Inspect the affected concern under `../../../modules/desktop/` or `../../../modules/agents/`, its consumers and checks. Desktop owns its native HM bridge, unstable-only guard and shared bundle; servers stay headless without HM/editors/agents.
2. Research actual locked NixOS/HM/application APIs before changing options. Use only the host's packages; retain native serialization, collision checks and the isolated Noctalia profile. Do not copy private app state or make store-backed settings writable.
3. Preserve one UWSM session owner and one shell/locker/polkit/notification service. Fingerprint remains an alternative to nonempty passwords, not empty-password authentication or keyring unlock. Keep the private AccountsService mode override: upstream otherwise re-enforces 0775 on service start.
4. For displays, retain physical DRM eligibility, EDID-gated HDR, exact Lua acknowledgement, subscriber-first sync and fresh active-external verification before panel disable. Propagate parsing/command/socket errors; no inferred eGPU or driver. Real modesetting is not a check.
5. For Wi-Fi, preserve both systemd/GLib escaping, root-only runtime files, marker rejection and no partial output. Never log values, relax campus CA/name validation or use literal-block credentials. Native printer provisioning stays manual-only: no boot query/retry or rebuild restart.
6. Keep zoxide initialization after Starship (HM #9349), only the two targeted duplicate-autostart masks, and manual browser-export imports. Zen's host-pkgs recipe retains the Firefox wrapper passthru adapter; `normal_installed` preserves pinned extension updates where `force_installed` would not.
7. For Pi, review the packaged retry classifier and message replacement ordering, bounded retries, all-sibling tool-call stripping and offline loader tests. `npm:` runtime packages remain mutable private home state; no automatic installs during checks. Preserve trust/rewind prompts and RTK privacy boundaries.
8. Run [manual validation](../validate/SKILL.md). Do not make ThinkPad ready to get a build: its new storage layout is still blocked. Any later activation, new Pi session, enrollment, printer contact, display transition or boot needs separate authorization and the reference's acceptance checklist.

## Completion

Source/generated-config tests pass, state and package boundaries remain intact, and untested authentication, network, graphical/peripheral and boot behavior is explicitly recorded.
