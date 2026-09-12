"""Check the actual native task graph and its independently required safety gates."""
import json
import os
from pathlib import Path
import shutil
import subprocess

root = Path(os.environ["DEVENV_ROOT"])
flake = json.loads((root / "flake.lock").read_text())
devenv = json.loads((root / "devenv.lock").read_text())
assert devenv["nodes"]["nixpkgs"] == flake["nodes"]["nixpkgs"], "Development/flake unstable pins differ"
assert devenv["nodes"]["devenv"]["original"] == {
    "owner": "cachix", "repo": "devenv", "type": "github",
}, "Keep the devenv source unversioned; revisions belong in devenv.lock"
tasks = {task["name"]: task for task in json.loads(Path(os.environ["DEVENV_TASK_FILE"]).read_text())}
expected = {"repo:" + name for name in (
    "fmt", "format-check", "lint", "secret-check", "secret-check-tests", "tooling-check",
    "evaluate", "check", "inventory", "tailscale-inventory", "tailscale-check", "revisions",
)}
assert {name for name in tasks if name.startswith("repo:")} == expected, "Review task inventory changes"
assert all(dep in tasks for task in tasks.values() for dep in task["before"] + task["after"]), \
    "Use existing task names without dependency suffixes; soft dependencies cannot gate safety checks"


def dependencies(name, visiting=frozenset()):
    assert name not in visiting, "Cyclic task graph"
    parents = set(tasks[name]["after"])
    parents.update(task["name"] for task in tasks.values() if name in task["before"])
    return parents | set().union(*(dependencies(parent, visiting | {name}) for parent in parents))


required = {"repo:" + name for name in ("secret-check", "format-check", "lint", "tooling-check", "evaluate")}
assert dependencies("repo:check") == required, "Canonical check lost a gate or gained a side effect"
assert "repo:secret-check" in dependencies("repo:evaluate"), "Ciphertext must be checked before evaluation"
assert not dependencies("devenv:enterShell") & expected, "Shell entry must not run repository operations"
for name in required | {"repo:check"}:
    assert tasks[name]["status"] is None and not tasks[name]["exec_if_modified"], "Never cache safety gates"

# Catch divergence in the duplicated one-line native OpenTofu package selection.
packaged = subprocess.check_output(
    ["nix", "eval", "--no-update-lock-file", "--raw", ".#packages.x86_64-linux.tailscale-tofu"],
    cwd=root, text=True,
).strip()
tofu = shutil.which("tofu")
assert tofu is not None, "OpenTofu is missing from the native environment"
assert Path(tofu).resolve() == Path(packaged) / "bin/tofu", "Use the exact checked OpenTofu/provider wrapper"
print("Native task graph, uncached safety gates, unstable lock and OpenTofu/provider parity passed.")
