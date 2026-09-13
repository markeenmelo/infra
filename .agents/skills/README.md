# Repository skills

Skills own the repository's procedures, architecture decisions, research and dated evidence. `docs/` and explanatory code comments were removed; important details live in each skill's `references/` directory. Historical records retain their original commands/results, not current execution instructions.

| Skill | Use |
|---|---|
| [fleet-operations](fleet-operations/SKILL.md) | Authoritative dated host status, hardware/credential/boot evidence and operation scope |
| [devenv](devenv/SKILL.md) | Native toolbox, explicit scaffold/install/deploy tasks and synchronized locks |
| [validate](validate/SKILL.md) | Ordered local checks, native task contract, ciphertext preflight and validation limits |
| [nix-research](nix-research/SKILL.md) | Pinned upstream API/release evidence before dependency-sensitive edits |
| [dendritic-nix](dendritic-nix/SKILL.md) | Architecture/refactors, class boundaries, retained ADRs and implementation rationale |
| [add-host](add-host/SKILL.md) | Explicit host identity/track/composition and genuine commissioning |
| [add-feature](add-feature/SKILL.md) | Cohesive concern-owned NixOS/Home Manager changes |
| [storage-disko](storage-disko/SKILL.md) | OS-disk design, reinstall runbook and NAS exclusion |
| [impermanence](impermanence/SKILL.md) | Durable state, ownership and explicitly authorized migration |
| [desktop](desktop/SKILL.md) | ThinkPad desktop, authentication, displays, Wi-Fi and Pi policy |
| [tailscale](tailscale/SKILL.md) | Staged clients, guarded policy/state/credential operations and recovery |
| [deploy](deploy/SKILL.md) | Dedicated deployment account, ordered groups, preflight and recovery |
| [update-inputs](update-inputs/SKILL.md) | Scoped stable, unstable or full dependency updates |

Standard [Agent Skills](https://agentskills.io/specification), shared without duplicated content:

- **Pi:** canonical `.agents/skills/<name>/SKILL.md`, discovered after project trust; invoke `/skill:NAME`.
- **Claude Code:** `.claude/skills/<name>` links to the canonical directory; invoke `/NAME`. Root `CLAUDE.md` imports `AGENTS.md`.
- Add the matching relative Claude link whenever adding a skill. Keep shared name/description frontmatter, no automatic command injection or preapproved tools. `scripts/agents/check-guidance.py` checks the import, inventory and link targets offline.
- Review trust and available skills in a new/reloaded session; read the canonical file directly if discovery is restricted. No plugin installation, runtime provider call or permission bypass is required. Compatibility checks do not establish live harness acceptance.

Commands run from the **repository root**, not the skill directory. Resolve file references relative to their containing skill/reference file. Start with [AGENTS.md](../../AGENTS.md); all procedures remain subordinate to current operation authorization. Prose-only changes use the [scoped documentation checks](validate/SKILL.md#documentation-only-changes), not fleet builds.
