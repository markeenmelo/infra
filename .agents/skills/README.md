# Repository skills

Skills own the repository's procedures, architecture decisions, research and dated evidence. `docs/` and explanatory code comments were removed; important details live in each skill's `references/` directory. Historical records retain their original commands/results, not current execution instructions.

| Skill | Use |
|---|---|
| [fleet-operations](fleet-operations/SKILL.md) | Authoritative dated host status, hardware/credential/boot evidence and operation scope |
| [devenv](devenv/SKILL.md) | Native toolbox, existing scripts and synchronized locks; no replacement tasks yet |
| [validate](validate/SKILL.md) | Ordered manual checks, ciphertext preflight and validation limits |
| [nix-research](nix-research/SKILL.md) | Pinned upstream API/release evidence before dependency-sensitive edits |
| [dendritic-nix](dendritic-nix/SKILL.md) | Architecture/refactors, class boundaries, retained ADRs and implementation rationale |
| [add-host](add-host/SKILL.md) | Explicit host identity/track/composition and genuine commissioning |
| [add-feature](add-feature/SKILL.md) | Cohesive concern-owned NixOS/Home Manager changes |
| [storage-disko](storage-disko/SKILL.md) | OS-disk design, reinstall runbook and NAS exclusion |
| [impermanence](impermanence/SKILL.md) | Durable state, ownership and explicitly authorized migration |
| [desktop](desktop/SKILL.md) | ThinkPad desktop, authentication, displays, Wi-Fi and Pi policy |
| [tailscale](tailscale/SKILL.md) | Staged clients, guarded policy/state/credential operations and recovery |
| [deploy](deploy/SKILL.md) | Manual single-host preflight, activation boundaries and recovery |
| [update-inputs](update-inputs/SKILL.md) | Scoped stable, unstable or full dependency updates |

Standard [Agent Skills](https://agentskills.io/specification): Pi discovers `.agents/skills/<name>/SKILL.md` after project trust. Use `/skill:NAME` after trust/reload, or read the file directly; no project extension is required.

Commands run from the **repository root**, not the skill directory. Resolve file references relative to their containing skill/reference file. Start with [AGENTS.md](../../AGENTS.md); all procedures remain subordinate to current operation authorization. Prose-only changes use the [scoped documentation checks](validate/SKILL.md#documentation-only-changes), not fleet builds.
