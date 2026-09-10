"""Synthetic CLI tests: never connect to tailscaled or read an auth key."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = str(Path(sys.argv.pop(1)).resolve())


class Reconcile(unittest.TestCase):
    def run_case(self, state="Running", mode="preserve", failure="", bad_tag=False, malformed=False, arguments=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            mock = root / "tailscale"
            mock.write_text(f"#!{sys.executable}\n" + """import json, os, pathlib, sys
root = pathlib.Path(os.environ['MOCK_ROOT'])
args = sys.argv[1:]
with (root / 'calls').open('a') as output:
    output.write(json.dumps(args) + '\\n')
if args[0] == os.environ.get('FAIL'):
    print('TEST-ONLY-PRIVATE-DIAGNOSTIC', file=sys.stderr)
    sys.exit(1)
if args[0] == 'status':
    if os.environ.get('MALFORMED') == '1':
        print('{}')
    else:
        state = 'Running' if (root / 'up').exists() else os.environ['STATE']
        tag = 'tag:fleet-bastion' if os.environ.get('BAD_TAG') == '1' else 'tag:fleet-thinkpad'
        print(json.dumps({'BackendState': state, 'Self': {'ID': 'TEST-ONLY-NODE', 'Tags': [tag]}}))
elif args[0] == 'up':
    (root / 'up').touch()
""")
            mock.chmod(0o755)
            env = os.environ | {
                "PATH": directory + os.pathsep + os.environ["PATH"],
                "MOCK_ROOT": directory, "STATE": state, "FAIL": failure,
                "BAD_TAG": "1" if bad_tag else "0", "MALFORMED": "1" if malformed else "0",
            }
            if arguments is None:
                arguments = [mode, "thinkpad", "tag:fleet-thinkpad", "/run/secrets/TEST-ONLY-tailscale" if mode == "auth-key" else ""]
            result = subprocess.run(["bash", SCRIPT, *arguments], env=env, capture_output=True, text=True, timeout=10)
            lines = (root / "calls").read_text().splitlines() if (root / "calls").exists() else []
            calls = [json.loads(line) for line in lines]
            self.assertNotIn("TEST-ONLY-PRIVATE-DIAGNOSTIC", result.stdout + result.stderr)
            self.assertFalse(any("--reset" in call or "--force-reauth" in call for call in calls))
            return result, calls

    def test_running_preserves_identity_and_reconciles(self):
        result, calls = self.run_case()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(call[0] == "up" for call in calls))
        settings = next(call for call in calls if call[0] == "set")
        for flag in ["--ssh=false", "--accept-routes=false", "--advertise-routes=", "--exit-node=", "--operator=", "--auto-update=false"]:
            self.assertIn(flag, settings)

    def test_running_never_resubmits_key(self):
        result, calls = self.run_case(mode="auth-key")
        self.assertEqual(result.returncode, 0)
        self.assertFalse(any(call[0] == "up" for call in calls))

    def test_enrollment_uses_file_reference_once(self):
        result, calls = self.run_case("NeedsLogin", "auth-key")
        self.assertEqual(result.returncode, 0, result.stderr)
        ups = [call for call in calls if call[0] == "up"]
        self.assertEqual(len(ups), 1)
        self.assertIn("--auth-key=file:/run/secrets/TEST-ONLY-tailscale", ups[0])
        self.assertIn("--advertise-tags=tag:fleet-thinkpad", ups[0])

    def test_preservation_cannot_enroll(self):
        result, calls = self.run_case("NeedsLogin")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call[0] in ["up", "set"] for call in calls))

    def test_stopped_reconnects_without_key(self):
        result, calls = self.run_case("Stopped", "auth-key")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call for call in calls if call[0] == "up"], [["up"]])

    def test_pending_approval_is_not_reenrollment(self):
        result, calls = self.run_case("NeedsMachineAuth", "auth-key")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call[0] in ["up", "set"] for call in calls))

    def test_failures_stop_progress(self):
        for failure, state in [("status", "Running"), ("up", "NeedsLogin"), ("set", "Running")]:
            with self.subTest(failure=failure):
                result, calls = self.run_case(state, "auth-key", failure=failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(calls[-1][0], failure)

    def test_argument_guards_run_before_cli(self):
        for arguments in [[], ["unset", "thinkpad", "tag:fleet-thinkpad", ""],
                          ["preserve", "thinkpad", "tag:fleet-bastion", ""],
                          ["preserve", "thinkpad", "tag:fleet-thinkpad", "/run/secrets/TEST"],
                          ["auth-key", "thinkpad", "tag:fleet-thinkpad", "/nix/store/TEST"],
                          ["auth-key", "thinkpad", "tag:fleet-thinkpad", "/run/secrets/../TEST"]]:
            with self.subTest(arguments=arguments):
                result, calls = self.run_case(arguments=arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(calls, [])

    def test_invalid_status_and_tag_fail(self):
        for kwargs in [{"bad_tag": True}, {"malformed": True}, {"state": "UnknownState"}]:
            with self.subTest(kwargs=kwargs):
                result, _ = self.run_case(**kwargs)
                self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
