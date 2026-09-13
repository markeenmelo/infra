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
        if not value or any((ord(c) < 32 and c != "\t") or ord(c) == 127 for c in value):
            raise ValueError("Expected a nonempty single-line credential")
        if value in ("__SET_SENECA_IDENTITY_LOCALLY__", "__SET_SENECA_PASSWORD_LOCALLY__"):
            raise ValueError("Campus credential placeholder has not been replaced")
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
        sys.exit("Wi-Fi credential preparation failed; review the root-owned SOPS files privately.")
