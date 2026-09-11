"""Wrapper guards plus native CLI isolation; disposable data, no real provider/API access."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(sys.argv.pop(1)).resolve()
NATIVE_TOFU = shutil.which("tofu")


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
assert os.environ['TF_WORKSPACE'] == 'default'
assert os.environ['TF_CLI_CONFIG_FILE'] == '/dev/null'
assert not os.environ.get('TF_REATTACH_PROVIDERS')
with (root / 'calls').open('a') as output:
    output.write(' '.join(sys.argv[1:]) + '\\n')
if sys.argv[1] == 'plan':
    destination = next((a[5:] for a in sys.argv if a.startswith('-out=')), None)
    if destination is not None:
        pathlib.Path(destination).write_text('TEST-ONLY-PLAN')
    if '-detailed-exitcode' in sys.argv:
        sys.exit(int(os.environ.get('MOCK_VERIFY_EXIT', '0')))
""")
        executable.chmod(0o755)
        self.state = self.root / "private-state"
        self.env = {
            "PATH": str(self.root) + os.pathsep + os.environ["PATH"],
            "HOME": str(self.root), "MOCK_ROOT": str(self.root),
            "TAILSCALE_TAILNET": "TEST-ONLY-TAILNET", "TAILSCALE_STATE_DIR": str(self.state),
            "TAILSCALE_OAUTH_CLIENT_ID": "TEST-ONLY-OAUTH-ID",
            "TAILSCALE_OAUTH_CLIENT_SECRET": "TEST-ONLY-OAUTH-SECRET",
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

    def test_verify_preserves_retained_files_and_exit_codes(self):
        self.assertEqual(self.run_command("init").returncode, 0)
        self.assertEqual(self.run_command("plan").returncode, 0)
        plan = self.state / "change.tfplan"
        plan.write_text("TEST-ONLY-RETAINED-APPLIED-PLAN")
        state = self.state / "terraform.tfstate"
        state.write_text("TEST-ONLY-MOCK-STATE")
        before = {path: path.read_bytes() for path in (plan, state)}
        for code in (0, 1, 2):
            with self.subTest(code=code):
                result = self.run_command("verify", {"MOCK_VERIFY_EXIT": str(code)})
                self.assertEqual(result.returncode, code, result.stderr)
                self.assertEqual(self.calls()[-1], "plan -input=false -lock-timeout=60s -detailed-exitcode")
                self.assertEqual({path: path.read_bytes() for path in before}, before)
        self.assertFalse(any(call.startswith("apply") for call in self.calls()))

    def test_verify_does_not_create_a_saved_plan(self):
        self.assertEqual(self.run_command("init").returncode, 0)
        self.assertEqual(self.run_command("verify").returncode, 0)
        self.assertFalse((self.state / "change.tfplan").exists())
        self.assertEqual(self.calls()[-1], "plan -input=false -lock-timeout=60s -detailed-exitcode")

    def test_verify_cannot_bypass_runtime_guards(self):
        self.assertEqual(self.run_command("init").returncode, 0)
        before = self.calls()
        for env in [{"TAILSCALE_TAILNET": "TEST-ONLY-DIFFERENT"},
                    {"TF_VAR_state_passphrase": ""}, {"TF_CLI_ARGS_plan": "-refresh=false"},
                    {"TF_LOG": "TRACE"}, {"TF_ENCRYPTION": "TEST-ONLY-override"}]:
            with self.subTest(env=env):
                self.assertNotEqual(self.run_command("verify", env).returncode, 0)
                self.assertEqual(self.calls(), before)
        (self.state / "tailnet-id").write_text("TEST-ONLY-DIFFERENT\n")
        self.assertNotEqual(self.run_command("verify").returncode, 0)
        self.assertEqual(self.calls(), before)

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
                    {"TAILSCALE_OAUTH_CLIENT_ID": ""},
                    {"TAILSCALE_OAUTH_CLIENT_SECRET": ""},
                    {"TAILSCALE_API_KEY": "TEST-ONLY-API-KEY"},
                    {"TAILSCALE_IDENTITY_TOKEN": "TEST-ONLY-IDENTITY-TOKEN"},
                    {"IDENTITY_TOKEN": "TEST-ONLY-LEGACY-IDENTITY-TOKEN"},
                    {"TAILSCALE_AUDIENCE": "TEST-ONLY-AUDIENCE"},
                    {"OAUTH_CLIENT_ID": "TEST-ONLY-LEGACY-ID"},
                    {"OAUTH_CLIENT_SECRET": "TEST-ONLY-LEGACY-SECRET"},
                    {"TAILSCALE_BASE_URL": "https://alternate.example.test"},
                    {"TAILSCALE_STATE_DIR": str(self.repo / "state")},
                    {"TAILSCALE_STATE_DIR": "/nix/store/TEST-ONLY-state"},
                    {"TF_ENCRYPTION": "TEST-ONLY-override"}, {"TF_LOG": "TRACE"},
                    {"TF_CLI_ARGS_plan": "-lock=false"}, {"TF_WORKSPACE": "different"},
                    {"TF_REATTACH_PROVIDERS": "{}"}]:
            with self.subTest(env=env):
                self.assertNotEqual(self.run_command("init", env).returncode, 0)
                self.assertEqual(self.calls(), [])

    def native_probe(self, *arguments):
        # Replace only the executable boundary with a native, non-network probe.
        assert NATIVE_TOFU is not None
        (self.root / "tofu").write_text(f"#!{sys.executable}\nimport os\n"
                                      f"os.execv({NATIVE_TOFU!r}, {[NATIVE_TOFU, *arguments]!r})\n")

    def test_saved_workspace_cannot_retarget_native_cli(self):
        self.assertEqual(self.run_command("init").returncode, 0)
        data = self.state / "provider-data"
        data.mkdir()
        selection = data / "environment"
        selection.write_text("TEST-ONLY-DIFFERENT")
        self.native_probe("workspace", "show")
        result = self.run_command("verify")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "default")
        self.assertEqual(selection.read_text(), "TEST-ONLY-DIFFERENT")

    def test_native_cli_ignores_home_and_environment_provider_overrides(self):
        self.assertEqual(self.run_command("init").returncode, 0)
        config = self.repo / "tofu/tailscale"
        (config / "main.tf").write_text('''terraform {
  required_providers {
    synthetic = { source = "example.test/fixture/synthetic", version = "1.0.0" }
  }
}
''')
        overrides = self.root / "override"
        overrides.mkdir()
        marker = self.root / "override-launched"
        executable = overrides / "terraform-provider-synthetic"
        executable.write_text(f"#!{sys.executable}\nfrom pathlib import Path\n"
                              f"Path({str(marker)!r}).touch()\n")
        executable.chmod(0o755)
        cli = 'provider_installation { dev_overrides { "example.test/fixture/synthetic" = ' + json.dumps(str(overrides)) + ' } }\n'
        paths = [self.root / ".tofurc", self.root / ".terraformrc",
                 self.root / ".terraform.d/override.tfrc", self.root / "custom.tfrc"]
        for path in paths:
            path.parent.mkdir(exist_ok=True)
            path.write_text(cli)
        self.native_probe("providers", "schema", "-json")
        # Prove this local override is executable without downloads/API access.
        assert NATIVE_TOFU is not None
        baseline = subprocess.run([NATIVE_TOFU, "providers", "schema", "-json"], cwd=config,
                                  env=self.env | {"TF_CLI_CONFIG_FILE": str(paths[-1])},
                                  capture_output=True, text=True, timeout=10)
        self.assertNotEqual(baseline.returncode, 0)  # The sentinel speaks no provider protocol.
        self.assertTrue(marker.exists(), baseline.stderr)
        marker.unlink()
        # No init/provider downloads: absent synthetic provider must fail before launch.
        for env in [{}, {"TF_CLI_CONFIG_FILE": str(paths[-1])},
                    {"TERRAFORM_CONFIG": str(paths[-1])}]:
            with self.subTest(env=env):
                result = self.run_command("verify", env)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(marker.exists(), result.stderr)
                self.assertNotIn("development overrides", result.stderr.lower())
                self.assertIn("inconsistent dependency lock file", result.stderr.lower())

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
