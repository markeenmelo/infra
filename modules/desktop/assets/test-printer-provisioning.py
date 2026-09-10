"""Check the native unit/script with mocked commands; never contact CUPS or a printer."""

import json
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile

script = Path(sys.argv[1]).read_text()
lpadmin = sys.argv[2]
unit = Path(sys.argv[3]).read_text()
assert "X-RestartIfChanged=false" in unit
assert "network-online.target" not in unit
assert script.count(lpadmin) == 2

MOCK = r'''
import json
import os
from pathlib import Path
import sys

command = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["CALLS"], "a") as stream:
    stream.write(json.dumps([command, args]) + "\n")
if command == "lpadmin":
    sys.exit(int(os.environ["PRINTER_STATUS"]))
assert command == "systemctl" and args == ["stop", "cups.service"]
'''

with tempfile.TemporaryDirectory(prefix="printer-provisioning-test-") as directory:
    root = Path(directory)
    for command in ["lpadmin", "systemctl"]:
        mock = root / command
        mock.write_text(f"#!{sys.executable}\n" + MOCK)
        mock.chmod(0o755)
    # Preserve the upstream generated shell (including set -e), changing only
    # the absolute lpadmin path to a fixture command. PATH contains no real
    # systemctl, lpadmin or network client.
    fixture = root / "provision"
    fixture.write_text(script.replace(lpadmin, shlex.quote(str(root / "lpadmin"))))
    fixture.chmod(0o755)
    calls = root / "calls"
    provision_args = ["-DEpson EcoTank ET-3850", "-meverywhere", "-oprinter-is-shared=false",
                      "-pEpson_ET-3850", "-vipps://192.168.4.20:631/ipp/print", "-E"]
    for status in [0, 9]:
        calls.write_text("")
        result = subprocess.run([str(fixture)], text=True, capture_output=True, timeout=10,
                                env={"PATH": directory, "CALLS": str(calls), "PRINTER_STATUS": str(status)})
        assert result.returncode == status, (result.returncode, result.stderr)
        recorded = [json.loads(line) for line in calls.read_text().splitlines()]
        expected = [["lpadmin", provision_args]]
        if status == 0:
            expected += [["lpadmin", ["-d", "Epson_ET-3850"]], ["systemctl", ["stop", "cups.service"]]]
        assert recorded == expected, recorded

print("Native manual printer provisioning: success and offline failure propagation passed.")
