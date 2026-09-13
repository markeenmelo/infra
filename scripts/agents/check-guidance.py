from pathlib import Path
import re
import sys

root = Path(sys.argv[1]).resolve()
assert (root / "CLAUDE.md").read_text() == "@AGENTS.md\n", "Claude must import the canonical instructions"
assert (root / "AGENTS.md").is_file()
canonical = root / ".agents/skills"
aliases = root / ".claude/skills"
skills = {path.parent.name: path for path in canonical.glob("*/SKILL.md")}
assert skills, "No repository skills found"
assert {path.name for path in aliases.iterdir()} == set(skills), "Claude skill inventory drift"
for name, path in sorted(skills.items()):
    assert re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name) and len(name) <= 64
    text = path.read_text()
    assert text.startswith("---\n")
    frontmatter, body = text[4:].split("\n---\n", 1)
    fields = dict(line.split(": ", 1) for line in frontmatter.splitlines())
    assert fields["name"] == name
    assert 0 < len(fields["description"]) <= 1024
    assert "allowed-tools" not in fields, "Skill discovery must not preapprove tools"
    assert not re.search(r"^\s*!`", body, re.MULTILINE), "Skills must not execute startup commands"
    alias = aliases / name
    assert alias.is_symlink() and alias.readlink() == Path(f"../../.agents/skills/{name}")
    assert alias.resolve() == path.parent.resolve()
    assert (alias / "SKILL.md").read_bytes() == path.read_bytes()
print(f"Shared instructions and {len(skills)} canonical Pi/Claude skills: OK")
