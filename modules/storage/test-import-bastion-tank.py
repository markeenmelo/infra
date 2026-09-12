"""Offline strict-import checks: synthetic identities, no real block devices/ZFS."""

import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

SCRIPT = Path(sys.argv[1]).resolve()
MOCK = r'''
import json, os
from pathlib import Path
import sys
root = Path(os.environ["TEST_ROOT"])
state_path = root / "state.json"
state = json.loads(state_path.read_text())
args = sys.argv[1:]
command = Path(sys.argv[0]).name
with (root / "calls.jsonl").open("a") as out:
    out.write(json.dumps([command, *args]) + "\n")

def save():
    state_path.write_text(json.dumps(state))

if command == "sleep":
    sys.exit(0)
if command == "zfs":
    if args[0] == "list":
        if state.get("missing_dataset"):
            sys.exit(1)
        print(args[-1])
    elif args[0] == "get":
        print(state.get(args[-2], {"mountpoint": "legacy", "encryption": "off"}[args[-2]]))
    else:
        sys.exit(90)
elif command == "zpool":
    if args[0] == "list":
        sys.exit(0 if state["imported"] else 1)
    elif args[0] == "get":
        values = {"guid": "1000", "readonly": state.get("access", "off"), "compatibility": "openzfs-2.4"}
        print(state.get("get_" + args[-2], values[args[-2]]))
    elif args[0] == "import":
        if "-N" not in args:
            print("pool: fixture\nid: " + state.get("scan_guid", "1000") + "\nstate: " + state.get("scan_state", "ONLINE"))
        else:
            readonly = "readonly=on" in args
            if state.get("readonly_fail" if readonly else "writable_fail"):
                sys.exit(1)
            state.update(imported=True, access="on" if readonly else "off")
            save()
    elif args[0] == "export":
        if state.get("export_fail"):
            sys.exit(1)
        state["imported"] = False
        save()
    elif args[0] == "status" and "-j" in args:
        if state.get("status_fail"):
            sys.exit(1)
        if state.get("invalid_json"):
            print("not JSON")
        else:
            if state.get("writable_invalid") and state.get("access") == "off":
                state["status"]["pools"]["1000"]["error_count"] = "1"
            print(json.dumps(state["status"]))
    else:
        sys.exit(91)
else:
    sys.exit(92)
'''


def vdev(kind, guid, **extra):
    return dict(vdev_type=kind, guid=guid, state="ONLINE", read_errors="0",
                write_errors="0", checksum_errors="0", **extra)


def run_case(change=None, *, imported=False, aliases="normal", blocks=True, attempts="2"):
    with tempfile.TemporaryDirectory(prefix="bastion-import-test-") as directory:
        root = Path(directory)
        for name in ("bin", "by-id", "devices"):
            (root / name).mkdir()
        members = [str(root / "by-id" / name) for name in ("fixture-a", "fixture-b")]
        for index, member in enumerate(members):
            device = root / "devices" / str(0 if aliases == "duplicate" else index)
            device.touch()
            Path(member).symlink_to(device)
        if aliases == "missing":
            Path(members[1]).unlink()
        leaves = {str(i): vdev("disk", str(i + 3000), path=member)
                  for i, member in enumerate(members)}
        mirror = vdev("mirror", "2000", vdevs=leaves)
        pool = dict(name="fixture", pool_guid="1000", state="ONLINE", error_count="0",
                    scan_stats=dict(errors="0", function="SCRUB", state="FINISHED"),
                    vdevs={"root": vdev("root", "1000", vdevs={"mirror": mirror})})
        state = dict(imported=imported, status={"pools": {"1000": pool}})
        if change:
            change(state, pool, mirror, leaves)
        (root / "state.json").write_text(json.dumps(state))
        executable = root / "bin" / "mock"
        executable.write_text(f"#!{sys.executable}\n{MOCK}")
        executable.chmod(0o755)
        for command in ("zpool", "zfs", "sleep"):
            (root / "bin" / command).symlink_to(executable)
        env = dict(os.environ, PATH=str(root / "bin") + os.pathsep + os.environ["PATH"],
                   TEST_ROOT=str(root), MOCK_BLOCKS="1" if blocks else "0",
                   BASTION_TANK_POOL="fixture", BASTION_TANK_POOL_GUID="1000",
                   BASTION_TANK_TOP_GUID="2000", BASTION_TANK_LEAF_GUIDS="3000 3001",
                   BASTION_TANK_MEMBER_ALIASES=" ".join(members),
                   BASTION_TANK_DATASETS="fixture/data fixture/other",
                   BASTION_TANK_DEV_NODES=str(root / "by-id"),
                   BASTION_TANK_IMPORT_ATTEMPTS=attempts)
        # Only the kernel block-device query is doubled. Real symlink,
        # canonical-path and duplicate-device checks still run unchanged.
        wrapper = r'''
        test() {
          if [[ $# == 2 && $1 == -b ]]; then
            [[ $MOCK_BLOCKS == 1 && $2 == "$TEST_ROOT/"* ]] && builtin test -f "$2"
          else
            builtin test "$@"
          fi
        }
        export -f test
        exec bash "$1"
        '''
        result = subprocess.run([shutil.which("bash"), "-c", wrapper, "test", str(SCRIPT)],
                                env=env, text=True, capture_output=True, timeout=20)
        calls_file = root / "calls.jsonl"
        calls = [json.loads(line) for line in calls_file.read_text().splitlines()] if calls_file.exists() else []
        final = json.loads((root / "state.json").read_text())
        return result, calls, final, members


def imports(calls):
    return [c for c in calls if c[:2] == ["zpool", "import"] and "-N" in c]


def setting(name, value):
    return lambda state, *_: state.update({name: value})


result, calls, final, members = run_case()
assert result.returncode == 0, result.stderr
expected_search = ["-d", members[0], "-d", members[1]]
assert imports(calls) == [
    ["zpool", "import", *expected_search, "-N", "-o", "readonly=on", "1000"],
    ["zpool", "import", *expected_search, "-N", "1000"],
]
assert calls.index(["zpool", "export", "fixture"]) < calls.index(imports(calls)[1])
assert final["imported"] and final["access"] == "off"
result, calls, _, _ = run_case(imported=True)
assert result.returncode == 0 and imports(calls) == [], result.stderr

# Each preserved identity/topology/health/dataset guard must reject both an
# already imported pool and the read-only preflight before writable import.
mutations = [
    setting("get_guid", "9999"), setting("get_readonly", "unexpected"),
    setting("get_compatibility", "off"), setting("mountpoint", "/unexpected"),
    setting("encryption", "aes-256-gcm"), setting("missing_dataset", True),
    setting("status_fail", True), setting("invalid_json", True),
    lambda s, p, *_: p.update(name="wrong"),
    lambda s, p, *_: p.update(pool_guid="9999"),
    lambda s, p, *_: p.update(state="DEGRADED"),
    lambda s, p, *_: p.update(error_count="1"),
    lambda s, p, *_: p["scan_stats"].update(errors="1"),
    lambda s, p, *_: p["scan_stats"].update(function="RESILVER", state="SCANNING"),
    lambda s, p, m, leaves: leaves["0"].update(resilver_deferred=True),
    lambda s, p, m, leaves: leaves["0"].update(path="/unreviewed/member"),
    lambda s, p, m, leaves: leaves["0"].update(guid="9999"),
    lambda s, p, m, leaves: leaves.pop("1"),
    lambda s, p, m, leaves: leaves.update(extra=copy.deepcopy(leaves["0"])),
    lambda s, p, m, leaves: m.update(guid="9999"),
    lambda s, p, m, leaves: m.update(vdev_type="raidz"),
    lambda s, p, *_: p["vdevs"].update(extra=copy.deepcopy(p["vdevs"]["root"])),
    lambda s, p, m, *_: p["vdevs"]["root"]["vdevs"].update(extra=copy.deepcopy(m)),
]
for field in ("dedup", "special", "logs", "l2cache", "spares", "removal_stats", "raidz_expand_stats"):
    mutations.append(lambda s, p, *_, field=field: p.update({field: {}}))
for level in ("root", "mirror", "leaf"):
    for field, value in (("state", "DEGRADED"), ("read_errors", "1"), ("write_errors", "1"), ("checksum_errors", "1")):
        def mutate(s, p, m, leaves, level=level, field=field, value=value):
            target = {"root": p["vdevs"]["root"], "mirror": m, "leaf": leaves["0"]}[level]
            target[field] = value
        mutations.append(mutate)
for index, mutation in enumerate(mutations):
    for imported in (False, True):
        result, calls, final, _ = run_case(mutation, imported=imported)
        assert result.returncode != 0, (index, imported)
        assert not any("readonly=on" not in call for call in imports(calls)), (index, calls)
        if not imported:
            assert not final["imported"], (index, calls)

for kwargs in (dict(aliases="missing"), dict(aliases="duplicate"), dict(blocks=False), dict(attempts="0")):
    result, calls, _, _ = run_case(**kwargs)
    assert result.returncode != 0 and imports(calls) == [], (kwargs, calls)
for name, value in (("scan_state", "DEGRADED"), ("scan_guid", "9999"), ("readonly_fail", True), ("export_fail", True)):
    result, calls, _, _ = run_case(setting(name, value))
    assert result.returncode != 0
    assert not any("readonly=on" not in call for call in imports(calls)), (name, calls)
for name in ("writable_fail", "writable_invalid"):
    result, _, final, _ = run_case(setting(name, True))
    assert result.returncode != 0 and not final["imported"], name
print(f"Strict import passed: success/idempotence, {len(mutations)} mutations in both states, device/retry/export/write failures; no real ZFS or disks.")
