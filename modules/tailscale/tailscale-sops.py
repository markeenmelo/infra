"""Operator-only SOPS delivery into the guarded OpenTofu process, never Nix/tasks."""
import json
import os
from pathlib import Path
import subprocess
import sys


KEYS = {"TAILSCALE_OAUTH_CLIENT_ID", "TAILSCALE_OAUTH_CLIENT_SECRET", "TF_VAR_state_passphrase"}
OPERATIONS = {"init", "plan", "verify", "apply", "import-policy", "import-dns"}


def unique_object(pairs):
    result = dict(pairs)
    if len(result) != len(pairs):
        raise ValueError("Duplicate credential keys")
    return result


def main():
    if len(sys.argv) != 3 or sys.argv[2] not in OPERATIONS:
        raise SystemExit("Usage: tailnet-sops ENCRYPTED.yaml init|plan|verify|apply|import-policy|import-dns")
    if not os.environ.get("TAILSCALE_STATE_DIR", "").startswith("/"):
        raise SystemExit("Set TAILSCALE_STATE_DIR to the existing reviewed absolute private path first.")
    if any(os.environ.get(key) for key in KEYS):
        raise SystemExit("Unset the OAuth/passphrase exports before selecting SOPS credentials.")
    if any(os.environ.get(key) for key in ("TF_LOG", "TF_LOG_PATH", "TF_LOG_CORE", "TF_LOG_PROVIDER", "DEVENV_TRACE_TO")):
        raise SystemExit("Disable debug/tracing for this credential-bearing workflow.")

    # Capture decryption diagnostics too: no plaintext, identity or SOPS error
    # payload is sent to the terminal. JSON is data, never sourced shell code.
    try:
        result = subprocess.run(
            ["sops", "decrypt", "--output-type", "json", str(Path(sys.argv[1]).resolve())],
            capture_output=True, check=True,
        )
        secrets = json.loads(result.stdout, object_pairs_hook=unique_object)
    except (OSError, subprocess.CalledProcessError, ValueError):
        raise SystemExit("SOPS decryption/JSON parsing failed (details withheld).") from None
    if (not isinstance(secrets, dict) or secrets.keys() != KEYS
            or any(not isinstance(value, str) or not value or any(c in value for c in "\0\r\n")
                   for value in secrets.values())):
        raise SystemExit("Expected exactly the three documented nonempty, single-line operator credentials.")

    # All existing target, state, encryption, provider and apply-confirmation
    # guards still run. Never make credentials task outputs or shell exports.
    wrapper = Path(__file__).with_name("tailscale-tofu.sh")
    try:
        os.execvpe("bash", ["bash", str(wrapper), sys.argv[2]], os.environ | secrets)
    except (OSError, ValueError):
        raise SystemExit("Cannot start the guarded OpenTofu wrapper.") from None


if __name__ == "__main__":
    main()
