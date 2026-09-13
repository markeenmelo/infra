import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys


if not __debug__:
    sys.exit("Refusing installer identity checks with Python optimization enabled")


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate manifest field")
        result[key] = value
    return result


def public_output(arguments):
    return subprocess.run(arguments, stdin=subprocess.DEVNULL, capture_output=True,
                          text=True, check=True, timeout=15).stdout.strip()


try:
    assert len(sys.argv) in {2, 3} and re.fullmatch(r"[a-z][a-z0-9-]*", sys.argv[1])
    host = sys.argv[1]
    root = Path(os.environ["DEVENV_ROOT"]).resolve()
    paths = [Path(os.environ[key]) for key in ["FLEET_INSTALL_EXTRA_FILES", "FLEET_INSTALL_IDENTITY", "FLEET_INSTALL_MANIFEST"]]
    for path in paths:
        assert path.is_absolute() and not path.is_symlink()
        resolved = path.resolve(strict=True)
        assert not resolved.is_relative_to(root) and not resolved.is_relative_to("/nix/store")
        info = path.stat()
        assert info.st_uid == os.getuid() and not info.st_mode & 0o077
    staging, identity, manifest = paths
    assert staging.is_dir() and identity.is_file() and manifest.is_file()
    assert not manifest.resolve().is_relative_to(staging.resolve())
    binding = json.loads(manifest.read_text(), object_pairs_hook=unique_object)
    assert set(binding) == {"host", "machineId", "sshHostFingerprint", "ageRecipient"}
    assert binding["host"] == host
    if len(sys.argv) == 3:
        assert binding["ageRecipient"] == json.loads(sys.argv[2])
    expected = {
        "persist/etc/machine-id",
        "persist/etc/ssh/ssh_host_ed25519_key",
        "persist/etc/ssh/ssh_host_ed25519_key.pub",
    }
    if binding["ageRecipient"] is not None:
        expected.add("persist/var/lib/sops-nix/key.txt")
    files = set()
    for path in staging.rglob("*"):
        info = path.lstat()
        assert info.st_uid == os.getuid() and not stat.S_ISLNK(info.st_mode)
        assert stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)
        assert not info.st_mode & 0o022
        if path.is_file():
            relative = path.relative_to(staging).as_posix()
            files.add(relative)
            if relative.endswith("key.txt") or relative.endswith("ssh_host_ed25519_key"):
                assert not info.st_mode & 0o077
    assert files == expected
    assert re.fullmatch(r"[a-f0-9]{32}", binding["machineId"]) and binding["machineId"] != "0" * 32
    assert (staging / "persist/etc/machine-id").read_text().strip() == binding["machineId"]
    assert re.fullmatch(r"SHA256:[A-Za-z0-9+/]{43}", binding["sshHostFingerprint"])
    private_key = staging / "persist/etc/ssh/ssh_host_ed25519_key"
    public_key = private_key.with_suffix(".pub")
    derived = public_output(["ssh-keygen", "-y", "-P", "", "-f", str(private_key)]).split()
    assert len(derived) == 2 and derived[0] == "ssh-ed25519"
    assert public_key.read_text().split()[:2] == derived
    fingerprint = public_output(["ssh-keygen", "-E", "sha256", "-lf", str(public_key)]).split()
    assert len(fingerprint) >= 2 and fingerprint[1] == binding["sshHostFingerprint"]
    if binding["ageRecipient"] is not None:
        assert re.fullmatch(r"age1[a-z0-9]+", binding["ageRecipient"])
        assert public_output(["age-keygen", "-y", str(staging / "persist/var/lib/sops-nix/key.txt")]) == binding["ageRecipient"]
except (KeyError, OSError, AssertionError, ValueError, TypeError, subprocess.SubprocessError):
    sys.exit("Refusing: unsafe installer paths/staging or selected-host machine/SSH/age identity mismatch against the independently reviewed manifest; contents withheld")
print("Selected-host staging ownership, allowlist, machine ID and derived public identities match the reviewed manifest; no secret contents disclosed.")
