# Repository agent skills

Standard Agent Skills using Pi's trusted-project discovery and the [Agent Skills specification](https://agentskills.io/specification). After trusting/reloading the repository in Pi, use `/skill:NAME`; otherwise read the corresponding file directly. No project plugin or executable extension is required.

| Skill | Procedure |
|---|---|
| [nix-research](nix-research/SKILL.md) | Verify current upstream facts before dependency-sensitive edits |
| [dendritic-nix](dendritic-nix/SKILL.md) | Plan/review structural refactors, class boundaries, shared values and discovery |
| [add-host](add-host/SKILL.md) | Add explicit identity, track, composition and commissioning facts |
| [add-feature](add-feature/SKILL.md) | Extend cohesive NixOS/Home Manager capabilities |
| [storage-disko](storage-disko/SKILL.md) | Review OS disk changes without endangering NAS data |
| [impermanence](impermanence/SKILL.md) | Decide, declare and migrate durable state |
| [deploy](deploy/SKILL.md) | Preflight, deploy deliberately and preserve recovery |
| [update-inputs](update-inputs/SKILL.md) | Separate stable, unstable and full dependency updates |
| [validate](validate/SKILL.md) | Choose documentation-only checks or full canonical non-destructive validation |

For a large refactor, start with [dendritic-nix](dendritic-nix/SKILL.md): record the baseline, move one concern at a time and compare behavior before expanding the change. Use `add-feature`/`add-host` for implementation and `validate` for the final candidate. The [reference comparison](../../docs/research.md#dendritic-skill-alignment--2026-09-11) explains why this repository retains its own importer and safety-gated fleet schema.

All commands assume the **repository root**, not the skill directory. Use [native devenv and its locked bootstrap](../../docs/development.md); `justfile` and the old devShell are removed. Resolve repository references from these skill directories via `../../..`. Each procedure remains subordinate to the current user's authorization and `AGENTS.md` safety rules. Their formatting/fleet-check/build steps apply to substantive implementation changes or deployment preflight; prose-only edits to any procedure instead use [documentation-only validation](../../docs/validation.md#documentation-only-changes).
