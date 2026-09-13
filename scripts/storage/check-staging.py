import os
from pathlib import Path
import stat
import sys

try:
    root = Path(os.environ["DEVENV_ROOT"]).resolve()
    paths = [Path(os.environ[key]) for key in ["FLEET_INSTALL_EXTRA_FILES", "FLEET_INSTALL_IDENTITY"]]
    for path in paths:
        assert path.is_absolute() and not path.is_symlink()
        resolved = path.resolve(strict=True)
        assert not resolved.is_relative_to(root) and not resolved.is_relative_to("/nix/store")
        info = path.stat()
        assert info.st_uid == os.getuid() and not info.st_mode & 0o077
    staging, identity = paths
    assert staging.is_dir() and identity.is_file()
    expected = {
        "persist/etc/machine-id",
        "persist/etc/ssh/ssh_host_ed25519_key",
        "persist/etc/ssh/ssh_host_ed25519_key.pub",
        "persist/var/lib/sops-nix/key.txt",
    }
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
except (KeyError, OSError, AssertionError):
    sys.exit("Refusing: provide owned private out-of-repository installer identity/staging with only reviewed machine-id, SSH host pair and age identity; no symlinks or unsafe modes")
print("Installer staging path/ownership/allowlist checked without reading secret contents; identity and recovery review remain operator prerequisites.")
