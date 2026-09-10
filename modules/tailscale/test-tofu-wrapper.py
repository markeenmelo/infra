"""Test the operator wrapper with a mock executable and disposable state only."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(sys.argv.pop(1)).resolve()


class Wrapper(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repo"
        (self.repo / "scripts").mkdir(parents=True)
        (self.repo / "tofu/tailscale").mkdir(parents=True)
        (self.repo / "tofu/tailscale/tailnet.json").write_text('{"id": "TEST-ONLY-TAILNET"}\n')
        self.script = self.repo / "scripts/tailscale-tofu.sh"
        shutil.copyfile(SCRIPT, self.script)
        executable = self.root / "tofu"
        executable.write_text(f"#!{sys.executable}\n" + """import os, pathlib, sys
root = pathlib.Path(os.environ['MOCK_ROOT'])
with (root / 'calls').open('a') as output:
    output.write(' '.join(sys.argv[1:]) + '\\n')
if sys.argv[1] == 'plan':
    pathlib.Path(next(a[5:] for a in sys.argv if a.startswith('-out='))).write_text('TEST-ONLY-PLAN')
""")
        executable.chmod(0o755)
        self.state = self.root / "private-state"
        self.env = {
            "PATH": str(self.root) + os.pathsep + os.environ["PATH"],
            "HOME": str(self.root), "MOCK_ROOT": str(self.root),
            "TAILSCALE_TAILNET": "TEST-ONLY-TAILNET", "TAILSCALE_STATE_DIR": str(self.state),
            "TF_VAR_state_passphrase": "TEST-ONLY-PASSPHRASE-NOT-A-REAL-SECRET-12345",
        }

    def run_command(self, operation, env=None, confirmation=""):
        return subprocess.run(["bash", str(self.script), operation], env=self.env | (env or {}),
                              input=confirmation, capture_output=True, text=True, timeout=10)

    def calls(self):
        path = self.root / "calls"
        return path.read_text().splitlines() if path.exists() else []

    def test_explicit_saved_plan_application(self):
        self.assertEqual(self.run_command("init").returncode, 0)
        self.assertEqual(self.state.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.run_command("plan").returncode, 0)
        self.assertNotEqual(self.run_command("apply", confirmation="no\n").returncode, 0)
        self.assertFalse(any(c.startswith("apply") for c in self.calls()))
        self.assertEqual(self.run_command("apply", confirmation="TEST-ONLY-TAILNET\n").returncode, 0)
        self.assertTrue(self.calls()[-1].startswith("apply -input=false -lock-timeout=60s "))
        self.assertNotEqual(self.run_command("plan").returncode, 0)
        self.assertNotIn(self.env["TF_VAR_state_passphrase"], "\n".join(self.calls()))

    def test_uses_checked_in_identity_without_environment(self):
        self.env.pop("TAILSCALE_TAILNET")
        result = self.run_command("init")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.state / "tailnet-id").read_text(), "TEST-ONLY-TAILNET\n")

    def test_invalid_checked_in_identity_never_initializes_state(self):
        for content in ['{}', '{"id": null}', '{"id": ""}', '{"id": "-"}', '{"id": "bad id"}', '{invalid']:
            with self.subTest(content=content):
                (self.repo / "tofu/tailscale/tailnet.json").write_text(content)
                self.assertNotEqual(self.run_command("init").returncode, 0)
                self.assertEqual(self.calls(), [])
                self.assertFalse(self.state.exists())

    def test_missing_or_unsafe_inputs_never_invoke_tofu(self):
        for env in [{"TAILSCALE_TAILNET": ""}, {"TAILSCALE_TAILNET": "-"},
                    {"TAILSCALE_TAILNET": "bad\nid"}, {"TF_VAR_state_passphrase": ""},
                    {"TAILSCALE_STATE_DIR": str(self.repo / "state")},
                    {"TAILSCALE_STATE_DIR": "/nix/store/TEST-ONLY-state"},
                    {"TF_ENCRYPTION": "TEST-ONLY-override"}, {"TF_LOG": "TRACE"},
                    {"TF_CLI_ARGS_plan": "-lock=false"}, {"TF_WORKSPACE": "different"}]:
            with self.subTest(env=env):
                self.assertNotEqual(self.run_command("init", env).returncode, 0)
                self.assertEqual(self.calls(), [])

    def test_wrong_directory_permissions_rejected(self):
        self.state.mkdir(mode=0o755)
        self.assertNotEqual(self.run_command("init").returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assertEqual(self.state.stat().st_mode & 0o777, 0o755)

    def test_state_binding_and_missing_plan(self):
        self.assertEqual(self.run_command("init").returncode, 0)
        before = self.calls()
        self.assertNotEqual(self.run_command("plan", {"TAILSCALE_TAILNET": "TEST-ONLY-DIFFERENT"}).returncode, 0)
        self.assertNotEqual(self.run_command("apply", confirmation="TEST-ONLY-TAILNET\n").returncode, 0)
        self.assertNotEqual(self.run_command("destroy").returncode, 0)
        (self.state / "tailnet-id").write_text("TEST-ONLY-DIFFERENT\n")
        self.assertNotEqual(self.run_command("plan").returncode, 0)
        self.assertEqual(self.calls(), before)

    def test_ignored_variables_cannot_override_confirmation(self):
        (self.repo / "tofu/tailscale/terraform.tfvars").write_text('tailnet = "TEST-ONLY-DIFFERENT"')
        self.assertNotEqual(self.run_command("init").returncode, 0)
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
