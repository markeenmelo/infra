# Repository agent skills

Standard Agent Skills, verified against Pi 0.84.4 project discovery and [agentskills.io](https://agentskills.io/specification). After trusting/reloading the repository in Pi, use `/skill:NAME`; otherwise read the corresponding file directly. No project plugin or executable extension is required.

| Skill | Procedure |
|---|---|
| [nix-research](nix-research/SKILL.md) | Verify current upstream facts before dependency-sensitive edits |
| [add-host](add-host/SKILL.md) | Add explicit identity, track, composition and commissioning facts |
| [add-feature](add-feature/SKILL.md) | Extend cohesive deferred capabilities |
| [storage-disko](storage-disko/SKILL.md) | Review OS disk changes without endangering NAS data |
| [impermanence](impermanence/SKILL.md) | Decide, declare and migrate durable state |
| [deploy](deploy/SKILL.md) | Preflight, deploy deliberately and preserve recovery |
| [update-inputs](update-inputs/SKILL.md) | Separate stable, unstable and full dependency updates |
| [validate](validate/SKILL.md) | Run the canonical non-destructive validation |

All commands assume the **repository root**, not the skill directory. Resolve repository references from these skill directories via `../../..`. Each procedure remains subordinate to the current user's authorization and `AGENTS.md` safety rules.
