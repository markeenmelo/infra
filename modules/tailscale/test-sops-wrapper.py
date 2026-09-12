"""Synthetic subprocess tests: no real identities, decryption, OpenTofu or API."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(sys.argv.pop(1)).resolve()
KEYS = {"TAILSCALE_OAUTH_CLIENT_ID", "TAILSCALE_OAUTH_CLIENT_SECRET", "TF_VAR_state_passphrase"}


class SopsWrapper(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.script = self.root / SCRIPT.name
        shutil.copyfile(SCRIPT, self.script)
        self.values = {
            "TAILSCALE_OAUTH_CLIENT_ID": "TEST-ONLY-ID",
            "TAILSCALE_OAUTH_CLIENT_SECRET": "TEST-ONLY-'$() `;=\\secret",
            "TF_VAR_state_passphrase": "TEST-ONLY-PASSPHRASE-1234567890123456789",
        }
        self.payload = self.root / "synthetic.json"
        self.payload.write_text(json.dumps(self.values))
        sops = self.root / "sops"
        sops.write_text(f"#!{sys.executable}\n" + '''import os, pathlib, sys
root = pathlib.Path(os.environ["MOCK_ROOT"])
assert sys.argv[1:4] == ["decrypt", "--output-type", "json"]
assert len(sys.argv) == 5
(root / "sops-called").touch()
if os.environ.get("MOCK_SOPS_FAIL"):
    print("TEST-ONLY-WITHHELD-ERROR", file=sys.stderr)
    sys.exit(1)
sys.stdout.buffer.write((root / "synthetic.json").read_bytes())
''')
        sops.chmod(0o755)
        (self.root / "tailscale-tofu.sh").write_text('''set -euo pipefail
python3 - "$1" <<'PY'
import json, os, pathlib, sys
root = pathlib.Path(os.environ["MOCK_ROOT"])
values = json.loads((root / "synthetic.json").read_text())
assert all(os.environ[key] == value for key, value in values.items())
assert os.environ["TAILSCALE_STATE_DIR"] == str(root / "state")
assert sys.argv[1] == "verify"
(root / "wrapper-called").touch()
sys.exit(int(os.environ.get("MOCK_EXIT", "0")))
PY
''')
        self.env = {"PATH": str(self.root) + os.pathsep + os.environ["PATH"],
                    "HOME": str(self.root), "MOCK_ROOT": str(self.root),
                    "TAILSCALE_STATE_DIR": str(self.root / "state")}

    def run_wrapper(self, operation="verify", extra=None):
        result = subprocess.run([sys.executable, str(self.script), str(self.root / "encrypted.yaml"), operation],
                                env=self.env | (extra or {}), capture_output=True, text=True, timeout=10)
        self.assertNotIn("Traceback", result.stderr)
        for value in [*self.values.values(), "TEST-ONLY-WITHHELD-ERROR"]:
            self.assertNotIn(value, result.stdout + result.stderr)
        return result

    def test_only_child_receives_exact_values_and_exit_status(self):
        for status in (0, 1, 2):
            result = self.run_wrapper(extra={"MOCK_EXIT": str(status)})
            self.assertEqual(result.returncode, status, result.stderr)
        self.assertTrue((self.root / "wrapper-called").exists())
        self.assertFalse(KEYS & self.env.keys())
        self.assertEqual(sorted(p.name for p in self.root.iterdir()),
                         sorted([SCRIPT.name, "sops", "synthetic.json", "tailscale-tofu.sh", "sops-called", "wrapper-called"]))

    def test_invalid_credentials_and_decryption_errors_stop(self):
        bad = ["not json", "[]", "{}", json.dumps(self.values | {"PATH": "/tmp"}),
               json.dumps(self.values)[:-1] + ', "TAILSCALE_OAUTH_CLIENT_ID": "TEST-ONLY-DUPLICATE"}',
               *[json.dumps(self.values | {"TAILSCALE_OAUTH_CLIENT_SECRET": value})
                 for value in (None, 42, "", "TEST\nONLY", "TEST\rONLY", "TEST\u0000ONLY", "TEST\ud800ONLY")]]
        for text in bad:
            with self.subTest(text=text):
                self.payload.write_text(text)
                self.assertNotEqual(self.run_wrapper().returncode, 0)
                self.assertFalse((self.root / "wrapper-called").exists())
        self.payload.write_text(json.dumps(self.values))
        self.assertNotEqual(self.run_wrapper(extra={"MOCK_SOPS_FAIL": "1"}).returncode, 0)
        self.assertFalse((self.root / "wrapper-called").exists())

    def test_preflight_does_not_decrypt(self):
        for operation, extra in [("destroy", {}), ("verify", {"TAILSCALE_STATE_DIR": ""}),
                                 ("verify", {"TAILSCALE_OAUTH_CLIENT_ID": "TEST-ONLY-CONFLICT"}),
                                 ("verify", {"TF_LOG": "TRACE"}), ("verify", {"DEVENV_TRACE_TO": "stderr"})]:
            with self.subTest(operation=operation, extra=extra):
                self.assertNotEqual(self.run_wrapper(operation, extra).returncode, 0)
                self.assertFalse((self.root / "sops-called").exists())
                self.assertFalse((self.root / "wrapper-called").exists())


if __name__ == "__main__":
    unittest.main()
