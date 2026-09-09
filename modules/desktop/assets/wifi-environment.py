"""Prepare a private systemd EnvironmentFile, not NetworkManager profiles.

SOPS provides raw values. Escape them for BOTH systemd's EnvironmentFile and
GLib's keyfile syntax before native ensureProfiles substitutes them. No shell
execution, secret argv, persistent output or diagnostic credential contents.
"""

import json
import os
from pathlib import Path
import sys
import tempfile


def encode(value):
    if "\0" in value:
        raise ValueError("NUL is not supported")
    for raw, escaped in (("\\", "\\\\"), ("\n", "\\n"), ("\r", "\\r"), ("\t", "\\t"), (" ", "\\s")):
        value = value.replace(raw, escaped)
    return json.dumps(value, ensure_ascii=False)


def prepare(output, entries):
    lines = []
    for name, filename in entries:
        if name not in ("HOME_WIFI_PSK", "SENECA_IDENTITY", "SENECA_PASSWORD"):
            raise ValueError("Unknown credential")
        value = Path(filename).read_text(encoding="utf-8")
        # Provision single-line SOPS scalars, not YAML literal blocks. Preserve
        # spaces and punctuation: do not silently change a user's password.
        if not value or any((ord(c) < 32 and c != "\t") or ord(c) == 127 for c in value):
            raise ValueError("Expected a nonempty single-line credential")
        if name == "SENECA_IDENTITY" and ("@" in value or any(c.isspace() for c in value)):
            raise ValueError("Expected the campus username before @")
        lines.append(f"{name}={encode(value)}\n")
    os.umask(0o077)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=output.parent, delete=False) as stream:
        stream.writelines(lines)
        temporary = Path(stream.name)
    temporary.replace(output)


if __name__ == "__main__":
    try:
        destination = Path(sys.argv[1])
        pairs = [argument.split("=", 1) for argument in sys.argv[2:]]
        prepare(destination, pairs)
    except Exception:
        # Never log the source values or a decoder/formatter's exception text.
        sys.exit("Wi-Fi credential preparation failed; review the root-owned SOPS files privately.")
