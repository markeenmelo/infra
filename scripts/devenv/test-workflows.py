import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE = Path(sys.argv.pop(1)).resolve()
DISKO = Path(sys.argv.pop(1))
SYSTEM = Path(sys.argv.pop(1))
SSH = Path(sys.argv.pop(1))
FINGERPRINT = "SHA256:" + "A" * 43
MOCK = r'''
import json
import os
from pathlib import Path
import sys
root = Path(os.environ["TEST_ROOT"])
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with (root / "calls").open("a") as stream:
    stream.write(json.dumps([name, args]) + "\n")
if name == "git":
    if args == ["rev-parse", "HEAD"]:
        print("TEST-ONLY-REVISION")
    elif os.environ.get("DIRTY"):
        print(" M TEST-ONLY")
elif name == "nix":
    if "eval" in args:
        attribute = args[-1]
        if attribute == ".#deploymentPlan":
            print((root / "plan.json").read_text())
        elif attribute.startswith(".#deploymentGroups."):
            print(json.dumps(["racknerd", "bastion"] if attribute.endswith("servers") else ["thinkpad"]))
        elif attribute.startswith(".#deploy.nodes."):
            host = attribute.rsplit(".", 1)[1]
            print(json.dumps({"sshUser": "deploy", "hostname": host + ".invalid", "sshOpts": ["-o", "StrictHostKeyChecking=yes", "-o", "BatchMode=yes"]}))
        elif attribute.startswith(".#fleetConfigurations.") and attribute.endswith(".config.fleet.secrets"):
            recipient = os.environ.get("TEST_AGE_RECIPIENT")
            print(json.dumps({"ageRecipient": recipient, "ageKeyFile": "/persist/var/lib/sops-nix/key.txt" if recipient else None,
                              "identityReviewed": recipient is not None}))
        elif attribute.startswith(".#fleet."):
            print(json.dumps({"storageMode": "provision", "osDisk": "/dev/disk/by-id/TEST-ONLY-OS"}))
        else:
            raise AssertionError(attribute)
    elif "build" in args and "--print-out-paths" in args:
        print(os.environ["TEST_DISKO"] if args[-1].endswith("diskoScript") else os.environ["TEST_SYSTEM"])
    elif "run" in args:
        assert ".#deploy-rs" in args
elif name == "ssh":
    if os.environ.get("FAIL_SSH"):
        sys.exit(7)
    if args[-1] == "nix config show trusted-users":
        print("root" if os.environ.get("NO_TRUST") else "root deploy")
    elif "bash -s" in args[-1]:
        if os.environ.get("FAIL_INVENTORY"):
            sys.exit(8)
        disk = {"type": "disk", "size": 123,
            "serial": "WRONG" if os.environ.get("WRONG_SERIAL") else "TEST-ONLY-SERIAL",
            "mountpoints": None if os.environ.get("MISSING_MOUNTPOINTS") else (["/TEST-ONLY-MOUNTED"] if os.environ.get("MOUNTED") else [None])}
        if os.environ.get("HOLDER_TYPE"):
            disk["children"] = [{"type": "part", "mountpoints": [None],
                "children": [{"type": os.environ["HOLDER_TYPE"], "mountpoints": [None]}]}]
        print(json.dumps({"blockdevices": [disk]}))
elif name == "ssh-keyscan":
    print("evaluation-only.invalid ssh-ed25519 TEST-ONLY-NOT-A-KEY")
elif name == "ssh-keygen":
    if "-y" in args:
        print("ssh-ed25519 TEST-ONLY-PUBLIC-KEY TEST-ONLY PRIVATE-KEY COMMENT")
    else:
        wrong = os.environ.get("WRONG_FINGERPRINT") and "known_hosts" in args[-1]
        print("256 SHA256:" + ("B" if wrong else "A") * 43 + " TEST-ONLY (ED25519)")
elif name == "age-keygen":
    print("age1testonly")
elif name == "nixos-anywhere":
    if os.environ.get("FAIL_INSTALLER"):
        sys.exit(9)
else:
    raise AssertionError(name)
'''


class Workflows(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="operator-workflow-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        shutil.copytree(SOURCE / "scripts", self.repo / "scripts")
        (self.repo / "modules/hosts").mkdir(parents=True)
        (self.root / "calls").write_text("")
        for path, label in [("scripts/devenv/preflight.sh", "preflight"),
                            ("scripts/fleet/ready.sh", "ready")]:
            (self.repo / path).chmod(0o600)
            (self.repo / path).write_text(f'printf \'["{label}", []]\\n\' >> "$TEST_ROOT/calls"\n')
        with (self.repo / "scripts/devenv/preflight.sh").open("a") as stream:
            stream.write('test -z "${FAIL_PREFLIGHT:-}"\n')
        with (self.repo / "scripts/fleet/ready.sh").open("a") as stream:
            stream.write('test "${1:-}" != "${FAIL_READY:-}"\n')
        binaries = self.root / "bin"
        binaries.mkdir()
        for name in ["git", "nix", "ssh", "ssh-keyscan", "ssh-keygen", "age-keygen", "nixos-anywhere"]:
            executable = binaries / name
            executable.write_text(f"#!{sys.executable}\n" + MOCK)
            executable.chmod(0o755)
        self.environment = dict(os.environ, DEVENV_ROOT=str(self.repo), TEST_ROOT=str(self.root),
                                TEST_DISKO=str(DISKO), TEST_SYSTEM=str(SYSTEM),
                                PATH=f"{binaries}:{os.environ['PATH']}")
        for key in ["LOCAL_KEY", "SSH_PRIVATE_KEY", "SSHPASS", "SHELLOPTS", "BASH_ENV"]:
            self.environment.pop(key, None)
        base = dict(ready=True, enable=True, hostname="evaluation-only.invalid", sshUser="deploy",
                    profileUser="root", transport="trusted-user", remoteBuild=True,
                    autoRollback=True, magicRollback=True, interactiveSudo=False,
                    sudo="sudo -n -u", bootOnly=False)
        self.plan = {"racknerd": dict(base), "bastion": dict(base, bootOnly=True),
                     "thinkpad": dict(base, ready=False, enable=False)}
        self.save_plan()
        self.staging = self.root / "staging"
        self.staging.mkdir(mode=0o700)
        for relative in ["persist/etc/machine-id", "persist/etc/ssh/ssh_host_ed25519_key",
                         "persist/etc/ssh/ssh_host_ed25519_key.pub"]:
            path = self.staging / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("TEST-ONLY-NOT-A-SECRET\n")
            path.chmod(0o600)
        identity = self.root / "TEST-ONLY-identity"
        identity.write_text("TEST-ONLY-NOT-A-KEY\n")
        identity.chmod(0o600)
        (self.staging / "persist/etc/machine-id").write_text("1" * 32 + "\n")
        (self.staging / "persist/etc/ssh/ssh_host_ed25519_key.pub").write_text("ssh-ed25519 TEST-ONLY-PUBLIC-KEY TEST-ONLY PUBLIC COMMENT\n")
        self.manifest = self.root / "manifest.json"
        self.binding = dict(host="racknerd", machineId="1" * 32,
                            sshHostFingerprint=FINGERPRINT, ageRecipient=None)
        self.manifest.write_text(json.dumps(self.binding))
        self.manifest.chmod(0o600)
        self.environment.update(FLEET_INSTALL_EXTRA_FILES=str(self.staging), FLEET_INSTALL_IDENTITY=str(identity),
                                FLEET_INSTALL_MANIFEST=str(self.manifest))

    def save_plan(self):
        (self.root / "plan.json").write_text(json.dumps(self.plan))

    def invoke(self, script, data, **environment):
        return subprocess.run(["bash", str(self.repo / "scripts/devenv" / script)],
                              env=dict(self.environment, DEVENV_TASK_INPUT=json.dumps(data), **environment),
                              capture_output=True, text=True, timeout=20)

    def calls(self):
        return [json.loads(line) for line in (self.root / "calls").read_text().splitlines()]

    def assert_no_remote(self):
        self.assertFalse(any(name in {"ssh", "ssh-keyscan", "nixos-anywhere"} or
                             (name == "nix" and "run" in args) for name, args in self.calls()))

    def deploy_data(self, target="servers", mode="boot"):
        return dict(target=target, mode=mode, confirm=f"DEPLOY {target} {mode}")

    def install_data(self):
        data = dict(host="racknerd", target="root@evaluation-only.invalid", port=22,
                    device="/dev/disk/by-id/TEST-ONLY-OS", identity="TEST-ONLY-SERIAL",
                    fingerprint=FINGERPRINT, planHash=hashlib.sha256(DISKO.read_bytes()).hexdigest())
        data["confirm"] = f"ERASE {data['host']} {data['target']} {data['device']} {data['identity']}"
        return data

    def test_scaffold_is_local_unready_and_does_not_overwrite(self):
        data = dict(name="test-only-new-host", system="x86_64-linux", track="stable", group="servers")
        result = self.invoke("host-create.sh", data)
        self.assertEqual(result.returncode, 0, result.stderr)
        directory = self.repo / "modules/hosts/test-only-new-host"
        self.assertEqual({path.name for path in directory.iterdir()}, {"host.nix", "hardware.nix", "disko.nix"})
        text = (directory / "host.nix").read_text()
        self.assertIn("ready = false", text)
        self.assertNotIn(".invalid", text)
        before = {path.name: path.read_bytes() for path in directory.iterdir()}
        self.assertNotEqual(self.invoke("host-create.sh", data).returncode, 0)
        self.assertEqual(before, {path.name: path.read_bytes() for path in directory.iterdir()})
        self.assertEqual(self.calls(), [])

    def test_scaffold_rejects_missing_invalid_or_extra_inputs(self):
        base = dict(name="test-only-host", system="x86_64-linux", track="stable", group="servers")
        for data in [{}, dict(base, name="../escape"), dict(base, system="aarch64-linux"),
                     dict(base, track="guess"), dict(base, ready=True)]:
            self.assertNotEqual(self.invoke("host-create.sh", data).returncode, 0)
        self.assertEqual(list((self.repo / "modules/hosts").iterdir()), [])
        self.assertEqual(self.calls(), [])

    def test_deploy_orders_targets_and_preserves_flags(self):
        result = self.invoke("deploy.sh", self.deploy_data())
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        remote = next(index for index, (name, _) in enumerate(calls) if name == "ssh")
        self.assertEqual(sum(name == "ready" for name, _ in calls[:remote]), 2)
        self.assertLess(next(i for i, (name, _) in enumerate(calls) if name == "preflight"), remote)
        self.assertEqual(calls[-1], ["nix", ["run", "--no-update-lock-file", ".#deploy-rs", "--",
                         "--checksigs", "--boot", "--targets", ".#racknerd", ".#bastion", "--", "--no-update-lock-file"]])

    def test_invalid_deploy_requests_never_contact_hosts(self):
        for data in [{}, dict(self.deploy_data(), confirm="yes"), dict(self.deploy_data(), extra=True),
                     self.deploy_data("workstations"), self.deploy_data("missing"), self.deploy_data(mode="switch")]:
            self.assertNotEqual(self.invoke("deploy.sh", data).returncode, 0)
        self.assert_no_remote()

    def test_any_ineligible_member_or_local_failure_stops_before_contact(self):
        baseline = dict(self.plan["bastion"])
        for field, value in [("ready", False), ("enable", False), ("remoteBuild", False),
                             ("magicRollback", False), ("sshUser", "root"), ("transport", "unsigned")]:
            self.plan["bastion"] = dict(baseline, **{field: value})
            self.save_plan()
            self.assertNotEqual(self.invoke("deploy.sh", self.deploy_data()).returncode, 0)
        self.plan["bastion"] = baseline
        self.save_plan()
        for environment in [{"FAIL_PREFLIGHT": "1"}, {"FAIL_READY": "bastion"}]:
            self.assertNotEqual(self.invoke("deploy.sh", self.deploy_data(), **environment).returncode, 0)
        self.assert_no_remote()

    def test_dirty_candidate_and_inherited_credentials_refuse_early(self):
        for environment in [{"DIRTY": "1"}, {"LOCAL_KEY": "TEST-ONLY"}, {"SSHPASS": "TEST-ONLY"}]:
            self.assertNotEqual(self.invoke("deploy.sh", self.deploy_data(), **environment).returncode, 0)
        self.assert_no_remote()

    def test_missing_remote_access_or_trust_stops_activation(self):
        for environment in [{"FAIL_SSH": "1"}, {"NO_TRUST": "1"}]:
            self.assertNotEqual(self.invoke("deploy.sh", self.deploy_data(), **environment).returncode, 0)
        self.assertFalse(any(name == "nix" and "run" in args for name, args in self.calls()))

    def test_install_uses_prebuilt_paths_and_only_explicit_phases(self):
        result = self.invoke("host-install.sh", self.install_data())
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        args = next(args for name, args in calls if name == "nixos-anywhere")
        self.assertEqual(args[:3], ["--store-paths", str(DISKO), str(SYSTEM)])
        self.assertEqual(args[args.index("--phases") + 1], "disko,install")
        self.assertEqual(args[args.index("--build-on") + 1], "local")
        self.assertNotIn("--copy-host-keys", args)
        self.assertLess(next(i for i, (name, _) in enumerate(calls) if name == "preflight"),
                        next(i for i, (name, _) in enumerate(calls) if name == "ssh-keyscan"))
        ssh_args = next(args for name, args in calls if name == "ssh")
        self.assertIn("StrictHostKeyChecking=yes", ssh_args)
        self.assertNotIn("StrictHostKeyChecking=no", ssh_args)

    def test_install_invalid_input_disk_plan_or_private_state_stops_before_network(self):
        for data in [{}, dict(self.install_data(), confirm="yes"), dict(self.install_data(), port=0),
                     dict(self.install_data(), planHash="0" * 64), dict(self.install_data(), extra=True)]:
            self.assertNotEqual(self.invoke("host-install.sh", data).returncode, 0)
        (self.staging / "unexpected").write_text("TEST-ONLY")
        self.assertNotEqual(self.invoke("host-install.sh", self.install_data()).returncode, 0)
        self.assert_no_remote()

    def test_staging_modes_symlinks_and_checkout_paths_refuse(self):
        self.staging.chmod(0o755)
        self.assertNotEqual(self.invoke("host-install.sh", self.install_data()).returncode, 0)
        self.staging.chmod(0o700)
        key = self.staging / "persist/etc/ssh/ssh_host_ed25519_key"
        key.chmod(0o644)
        self.assertNotEqual(self.invoke("host-install.sh", self.install_data()).returncode, 0)
        key.unlink()
        key.symlink_to(self.root / "TEST-ONLY-MISSING")
        self.assertNotEqual(self.invoke("host-install.sh", self.install_data()).returncode, 0)
        key.unlink()
        key.write_text("TEST-ONLY-NOT-A-SECRET\n")
        key.chmod(0o600)
        checkout_staging = self.repo / "TEST-ONLY-STAGING"
        shutil.copytree(self.staging, checkout_staging)
        self.assertNotEqual(self.invoke("host-install.sh", self.install_data(),
                                        FLEET_INSTALL_EXTRA_FILES=str(checkout_staging)).returncode, 0)
        self.assert_no_remote()

    def test_install_requires_age_only_for_selected_secrets(self):
        result = self.invoke("host-install.sh", self.install_data(), TEST_AGE_RECIPIENT="age1testonly")
        self.assertNotEqual(result.returncode, 0)
        self.assert_no_remote()
        key = self.staging / "persist/var/lib/sops-nix/key.txt"
        key.parent.mkdir(parents=True)
        key.write_text("TEST-ONLY-NOT-A-SECRET\n")
        key.chmod(0o600)
        self.manifest.write_text(json.dumps(dict(self.binding, ageRecipient="age1testonly")))
        result = self.invoke("host-install.sh", self.install_data(), TEST_AGE_RECIPIENT="age1testonly")
        self.assertEqual(result.returncode, 0, result.stderr)
        (self.root / "calls").write_text("")
        self.assertNotEqual(self.invoke("host-install.sh", self.install_data()).returncode, 0)
        self.manifest.write_text(json.dumps(dict(self.binding, ageRecipient="age1wrong")))
        self.assertNotEqual(self.invoke("host-install.sh", self.install_data(), TEST_AGE_RECIPIENT="age1testonly").returncode, 0)
        self.assert_no_remote()

    def test_staging_is_bound_to_host_and_all_public_identities(self):
        for field, value in [("host", "bastion"), ("machineId", "2" * 32),
                             ("sshHostFingerprint", "SHA256:" + "B" * 43), ("ageRecipient", "age1wrong")]:
            self.manifest.write_text(json.dumps(dict(self.binding, **{field: value})))
            self.assertNotEqual(self.invoke("host-install.sh", self.install_data()).returncode, 0)
        self.manifest.write_text(json.dumps(self.binding))
        self.assertNotEqual(self.invoke("host-install.sh", self.install_data(), PYTHONOPTIMIZE="1").returncode, 0)
        for public in ["ssh-ed25519 TEST-ONLY-WRONG-KEY\n", "ssh-ed25519 TEST-ONLY-PUBLIC-KEY\n" * 2]:
            (self.staging / "persist/etc/ssh/ssh_host_ed25519_key.pub").write_text(public)
            self.assertNotEqual(self.invoke("host-install.sh", self.install_data()).returncode, 0)
        self.assert_no_remote()

    def test_unmounted_dm_lvm_raid_consumers_never_install(self):
        for holder in ["crypt", "lvm", "raid1", "mpath"]:
            self.assertNotEqual(self.invoke("host-install.sh", self.install_data(), HOLDER_TYPE=holder).returncode, 0)
        self.assertFalse(any(name == "nixos-anywhere" for name, _ in self.calls()))

    def test_kernel_holders_are_checked_for_disk_and_partitions(self):
        sysfs = self.root / "TEST-ONLY-SYSFS"
        for node in ["testdisk", "testdisk1"]:
            (sysfs / node / "holders").mkdir(parents=True)
        def invoke():
            return subprocess.run(["bash", "-c", 'source "$1"; check_kernel_holders "$2" "$3"', "test-only",
                                   str(SOURCE / "scripts/storage/installer-inventory.sh"), str(sysfs), "testdisk\ntestdisk1"],
                                  env=self.environment, capture_output=True, text=True, timeout=10)
        self.assertEqual(invoke().returncode, 0)
        for node in ["testdisk", "testdisk1"]:
            holder = sysfs / node / "holders/test-holder"
            holder.symlink_to(sysfs / "TEST-ONLY-DM")
            self.assertNotEqual(invoke().returncode, 0)
            holder.unlink()
        (sysfs / "testdisk1/holders").rmdir()
        self.assertNotEqual(invoke().returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_installer_identity_inventory_and_mount_failures_never_install(self):
        for environment in [{"WRONG_FINGERPRINT": "1"}, {"FAIL_INVENTORY": "1"},
                            {"WRONG_SERIAL": "1"}, {"MOUNTED": "1"}, {"MISSING_MOUNTPOINTS": "1"}]:
            self.assertNotEqual(self.invoke("host-install.sh", self.install_data(), **environment).returncode, 0)
        self.assertFalse(any(name == "nixos-anywhere" for name, _ in self.calls()))

    def test_live_inventory_guards_without_devices_or_contact(self):
        script = r'''
id() { printf '0\n'; }
grep() { if [[ $* == *VARIANT_ID* ]]; then return 0; else command grep "$@"; fi; }
findmnt() { if [[ $* == *FSTYPE* ]]; then printf 'overlay\n'; else printf '%s\n' "$TEST_MOUNTS"; fi; }
zpool() { printf '%s' "$TEST_POOLS"; return "${TEST_POOL_EXIT:-0}"; }
readlink() { echo UNEXPECTED-DEVICE-ACCESS >&2; return 99; }
swapon() { printf '%s' "${TEST_SWAP:-}"; }
export -f id grep findmnt zpool readlink swapon
exec bash "$TEST_INVENTORY" /dev/disk/by-id/TEST-ONLY-OS
'''
        for mounts, pools, status, message in [("/mnt/persist", "", "0", "existing /mnt mounts"),
                                              ("/", "TEST-ONLY-POOL", "0", "ZFS pool is imported"),
                                              ("/", "", "9", ""),
                                              ("/", "", "0", "any swap is active")]:
            result = subprocess.run(["bash", "-c", script], capture_output=True, text=True, timeout=10,
                                    env=dict(self.environment, TEST_MOUNTS=mounts, TEST_POOLS=pools,
                                             TEST_POOL_EXIT=status, TEST_SWAP="TEST-ONLY-SWAP" if message == "any swap is active" else "",
                                             TEST_INVENTORY=str(SOURCE / "scripts/storage/installer-inventory.sh")))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(message, result.stderr)
            self.assertNotIn("UNEXPECTED-DEVICE-ACCESS", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_installer_failure_is_not_success(self):
        result = self.invoke("host-install.sh", self.install_data(), FAIL_INSTALLER="1")
        self.assertEqual(result.returncode, 9)
        self.assertNotIn("returned successfully", result.stdout)

    def test_native_ssh_settings_override_upstream_unsafe_defaults_without_connecting(self):
        result = subprocess.run(["bash", str(SOURCE / "scripts/storage/installer-ssh.sh"),
                                 "-G", "-F", "/dev/null", "-o", "StrictHostKeyChecking=no",
                                 "-o", "UserKnownHostsFile=/dev/null", "-o", "IdentitiesOnly=no",
                                 "root@evaluation-only.invalid"],
                                env=dict(self.environment, FLEET_REAL_SSH=str(SSH),
                                         FLEET_INSTALL_KNOWN_HOSTS=str(self.root / "known_hosts")),
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("stricthostkeychecking true\n", result.stdout)
        self.assertIn("identitiesonly yes\n", result.stdout)
        self.assertIn("batchmode yes\n", result.stdout)
        self.assertIn(f"userknownhostsfile {self.root}/known_hosts\n", result.stdout)
        self.assertEqual(self.calls(), [])


unittest.main()
