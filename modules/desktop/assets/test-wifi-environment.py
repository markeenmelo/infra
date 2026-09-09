"""Synthetic, offline tests. Never read SOPS files or contact NetworkManager."""

import ctypes
import importlib.util
from pathlib import Path
import shlex
import stat
import subprocess
import sys
import tempfile

spec = importlib.util.spec_from_file_location("wifi_environment", sys.argv[1])
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)

glib = ctypes.CDLL(sys.argv[2])
glib.g_key_file_new.restype = ctypes.c_void_p
glib.g_key_file_load_from_data.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_int, ctypes.c_void_p]
glib.g_key_file_load_from_data.restype = ctypes.c_int
glib.g_key_file_get_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_void_p]
glib.g_key_file_get_string.restype = ctypes.c_void_p
glib.g_key_file_unref.argtypes = [ctypes.c_void_p]
glib.g_free.argtypes = [ctypes.c_void_p]


def get_string(data, group, key):
    keyfile = glib.g_key_file_new()
    try:
        data = data.encode()
        assert glib.g_key_file_load_from_data(keyfile, data, len(data), 0, None)
        pointer = glib.g_key_file_get_string(keyfile, group.encode(), key.encode(), None)
        assert pointer
        try:
            return ctypes.string_at(pointer).decode()
        finally:
            glib.g_free(pointer)
    finally:
        glib.g_key_file_unref(keyfile)


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    source = root / "synthetic-secret"
    output = root / "credentials.env"
    # Quotes, dollars, backslashes, comment characters, spaces and Unicode must
    # survive both parsers, without secondary expansion or keyfile injection.
    values = ["TEST-ONLY-password", "  TEST ' \" \\ $USER ${HOME_WIFI_PSK} `id` # ; ü ", "TEST\tONLY"]
    for value in values:
        source.write_text(value)
        helper.prepare(output, [("HOME_WIFI_PSK", source)])
        assert stat.S_IMODE(output.stat().st_mode) == 0o600
        # These generated double-quoted lines use the POSIX quote/backslash
        # subset supported by systemd EnvironmentFile (no variable expansion).
        environment = dict(token.split("=", 1) for token in shlex.split(output.read_text()))
        result = subprocess.run([sys.argv[3]], input="[wifi-security]\npsk=$HOME_WIFI_PSK\n", env=environment, text=True, capture_output=True, check=True)
        assert get_string(result.stdout, "wifi-security", "psk") == value

    for name, value in [("HOME_WIFI_PSK", ""), ("HOME_WIFI_PSK", "TEST\nINJECTION=yes"), ("HOME_WIFI_PSK", "TEST\0ONLY"), ("HOME_WIFI_PSK", "TEST\aONLY"), ("HOME_WIFI_PSK", "TEST\x7fONLY"), ("SENECA_IDENTITY", "TEST-ONLY@example.invalid"), ("SENECA_IDENTITY", "TEST ONLY")]:
        source.write_text(value)
        result = subprocess.run([sys.executable, sys.argv[1], str(output), f"{name}={source}"], capture_output=True, text=True)
        assert result.returncode != 0 and result.stdout == ""
        assert result.stderr == "Wi-Fi credential preparation failed; review the root-owned SOPS files privately.\n"

    source.write_text("TEST-ONLY-campus-user")
    helper.prepare(output, [("SENECA_IDENTITY", source), ("SENECA_PASSWORD", source)])
    assert len(output.read_text().splitlines()) == 2
    assert not (root / "INJECTION").exists()

print("Synthetic Wi-Fi environment/GLib round trips, permissions and fail-closed diagnostics passed.")
