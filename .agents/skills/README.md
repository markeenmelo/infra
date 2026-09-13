# Skills

Procedures for this repository. One `SKILL.md` each, no reference trees — the code and `git log` hold the details.

| Skill | Use |
|---|---|
| [dendritic-nix](dendritic-nix/SKILL.md) | Architecture, module boundaries, adding a feature or a host |
| [storage](storage/SKILL.md) | Disko layouts, persistence, installation |
| [deploy](deploy/SKILL.md) | Activation with deploy-rs, groups, rollback |
| [desktop](desktop/SKILL.md) | ThinkPad desktop, Home Manager, displays |

Pi reads these directly (`/skill:NAME` after project trust); Claude Code reads the same files through the `.claude/skills/` links (`/NAME`). Add both when adding a skill. Run commands from the repository root, and read [AGENTS.md](../../AGENTS.md) first — no skill overrides it.
