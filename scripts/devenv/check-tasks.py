import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
expected = {
    "host:create": ("host-create.sh", {"name", "system", "track", "group"}),
    "host:install": ("host-install.sh", {"host", "target", "port", "device", "identity", "fingerprint", "planHash", "confirm"}),
    "deploy:run": ("deploy.sh", {"target", "mode", "confirm"}),
}
tasks = json.loads(Path(sys.argv[1]).read_text())
assert isinstance(tasks, list)
owned = {task["name"]: task for task in tasks if not task["name"].startswith("devenv:")}
assert set(owned) == set(expected), "Unexpected repository task inventory"
for name, (source, fields) in expected.items():
    task = owned[name]
    assert task["type"] == "oneshot" and task["show_output"]
    assert task["before"] == [] and task["after"] == []
    assert task["status"] is None and task["exec_if_modified"] == []
    assert task["input"] == dict.fromkeys(fields)
    assert task["env"] == {}
    assert (root / "scripts/devenv" / source).read_text() in Path(task["command"]).read_text()
for task in tasks:
    for dependency in task["before"] + task["after"]:
        selector = dependency.split("@")[0]
        assert not any(name == selector or name.startswith(selector + ":") for name in expected), "Operator task pulled into another task graph"
print("Three explicit uncached operator tasks; no lifecycle/dependency edges or credential inputs: OK")
