import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import unittest

POLICY = Path(sys.argv.pop(1)).read_text()
INTERNAL = {
    "name": "eDP-1", "width": 1920, "height": 1200, "refreshRate": 60.003,
    "availableModes": ["1920x1200@60.00Hz"], "disabled": True, "dpmsStatus": True,
}
EXTERNAL = {
    "name": "DP-TEST", "width": 1280, "height": 720, "refreshRate": 60,
    "availableModes": ["2560x1440@60.00Hz", "1280x720@60.00Hz"], "disabled": False,
    "dpmsStatus": True,
}
FALLBACK = {
    "name": "FALLBACK", "width": 1920, "height": 1080, "refreshRate": 60,
    "availableModes": [], "disabled": False,
}
HDR = "BT2020RGB\nSMPTE ST2084\nHDR Static Metadata Data Block:\n"
PANEL = ('hl.monitor({ output = "eDP-1", mode = "1920x1200@60.003", position = "0x0", '
         'scale = 1, bitdepth = 8, cm = "srgb", vrr = 0, disabled = false })')
SDR_RULE = ('hl.monitor({ output = "DP-TEST", mode = "preferred", position = "0x0", '
            'scale = 1, bitdepth = 8, cm = "srgb", vrr = 0, disabled = false })')
HDR_RULE = SDR_RULE.replace('bitdepth = 8, cm = "srgb"', 'bitdepth = 10, cm = "hdredid"')
DISABLED_PANEL = 'hl.monitor({ output = "eDP-1", disabled = true })'

MOCK = r'''
import json
import os
from pathlib import Path
import sys

root = Path(os.environ["FIXTURE"])
command = Path(sys.argv[0]).name
args = sys.argv[1:]
if command == "hyprctl":
    if args == ["monitors", "all", "-j"]:
        query = int((root / "queries").read_text()) + 1
        (root / "queries").write_text(str(query))
        if query == int(os.environ.get("FAIL_QUERY", "0")):
            sys.exit(6)
        snapshots = json.loads((root / "snapshots").read_text())
        sys.stdout.write(snapshots[min(query - 1, len(snapshots) - 1)])
    elif args == ["monitors", "-j"]:
        if os.environ.get("FAIL_ACTIVE_QUERY"):
            sys.exit(6)
        if (root / "active").exists():
            sys.stdout.write((root / "active").read_text())
        else:
            query = int((root / "queries").read_text())
            snapshots = json.loads((root / "snapshots").read_text())
            snapshot = json.loads(snapshots[min(query - 1, len(snapshots) - 1)])
            print(json.dumps([m for m in snapshot if not m["disabled"]]))
    elif args[:2] == ["keyword", "monitor"]:
        print("keyword can't work with non-legacy parsers. Use eval.")
    else:
        assert len(args) == 2 and args[0] == "eval"
        assert args[1].startswith("hl.monitor({ ") and args[1].endswith(" })")
        query = int((root / "queries").read_text())
        with (root / "rules").open("a") as stream:
            stream.write(json.dumps([query, args[1]]) + "\n")
        if (query == int(os.environ.get("FAIL_RULE_QUERY", "0"))
                and f'output = "{os.environ["FAIL_RULE_NAME"]}"' in args[1]):
            sys.exit(7)
        print(os.environ.get("RULE_REPLY", "ok"))
elif command == "edid-decode":
    edid = json.loads(Path(args[0]).read_text())
    sys.stdout.write(edid["text"])
    sys.exit(edid["status"])
elif command == "socat":
    assert args == ["-u", f"UNIX-CONNECT:{root}/runtime/hypr/TEST-ONLY/.socket2.sock",
                    "SYSTEM:echo subscribed; exec cat,nofork"]
    status = int(os.environ.get("SOCKET_STATUS", "0"))
    if status:
        sys.exit(status)
    print("subscribed")
    sys.stdout.write((root / "events").read_text())
elif command == "sleep":
    connector = os.environ.get("CONNECT_ON_SLEEP")
    if connector:
        (root / f"drm/card9-{connector}/status").write_text("connected\n")
else:
    raise AssertionError(command)
'''


class OutputPolicyTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="output-policy-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / "runtime").mkdir()
        (self.root / "drm").mkdir()
        lid = self.root / "lid/TEST-ONLY"
        lid.mkdir(parents=True)
        (lid / "state").write_text("state: closed\n")
        (self.root / "queries").write_text("0")
        (self.root / "rules").write_text("")
        (self.root / "events").write_text("")
        binaries = self.root / "bin"
        binaries.mkdir()
        for name in ["hyprctl", "edid-decode", "socat", "sleep"]:
            executable = binaries / name
            executable.write_text(f"#!{sys.executable}\n" + MOCK)
            executable.chmod(0o755)
        self.script = self.root / "policy.sh"
        assert "/sys/class/drm/" in POLICY and "/proc/acpi/button/lid/" in POLICY
        self.script.write_text(POLICY.replace("/sys/class/drm/", f"{self.root}/drm/")
                               .replace("/proc/acpi/button/lid/", f"{self.root}/lid/"))
        self.environment = dict(os.environ, FIXTURE=str(self.root),
                                XDG_RUNTIME_DIR=str(self.root / "runtime"),
                                HYPRLAND_INSTANCE_SIGNATURE="TEST-ONLY",
                                PATH=f"{binaries}:{os.environ['PATH']}")
        self.snapshots([INTERNAL, EXTERNAL])

    def snapshots(self, *snapshots):
        (self.root / "snapshots").write_text(json.dumps([
            snapshot if isinstance(snapshot, str) else json.dumps(snapshot)
            for snapshot in snapshots
        ]))

    def connector(self, name="DP-TEST", *, connected=True, hdr=False, status=0):
        connector = self.root / f"drm/card9-{name}"
        connector.mkdir()
        (connector / "status").write_text("connected\n" if connected else "disconnected\n")
        (connector / "edid").write_text(json.dumps({"text": HDR if hdr else "SDR\n", "status": status}))

    def invoke(self, action="sync", **environment):
        return subprocess.run(["bash", str(self.script), action], text=True,
                              capture_output=True, timeout=10,
                              env=dict(self.environment, **environment))

    def rules(self):
        return [json.loads(line) for line in (self.root / "rules").read_text().splitlines()]

    def test_disabled_panel_and_fallback_restore_panel(self):
        self.snapshots([INTERNAL, FALLBACK])
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.rules(), [[1, PANEL]])

    def test_virtual_and_disconnected_outputs_do_not_replace_panel(self):
        self.connector(connected=False)
        self.snapshots([INTERNAL, FALLBACK, EXTERNAL, dict(EXTERNAL, name="TEST-ONLY-VIRTUAL")])
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.rules(), [[1, PANEL]])

    def test_closed_lid_with_physical_external(self):
        self.connector()
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.rules(), [[1, SDR_RULE], [1, DISABLED_PANEL]])

    def test_inactive_external_never_disables_panel(self):
        self.connector()
        self.snapshots([dict(INTERNAL, disabled=False), EXTERNAL])
        for active in [[], [FALLBACK], [dict(EXTERNAL, disabled=True)],
                       [dict(EXTERNAL, dpmsStatus=False)], [dict(EXTERNAL, width=0)]]:
            with self.subTest(active=active):
                (self.root / "rules").write_text("")
                (self.root / "active").write_text(json.dumps(active))
                result = self.invoke()
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("refusing to disable panel", result.stderr)
                self.assertEqual([rule for _, rule in self.rules()], [SDR_RULE])

    def test_active_snapshot_errors_stop_before_panel(self):
        self.connector()
        for active in ["", "[", "{}", "[] []", "[7]",
                       json.dumps([dict(EXTERNAL, dpmsStatus="true")])]:
            with self.subTest(active=active):
                (self.root / "rules").write_text("")
                (self.root / "active").write_text(active)
                result = self.invoke()
                self.assertNotEqual(result.returncode, 0)
                self.assertNotEqual(result.stderr, "")
                self.assertEqual([rule for _, rule in self.rules()], [SDR_RULE])
        (self.root / "rules").write_text("")
        result = self.invoke(FAIL_ACTIVE_QUERY="1")
        self.assertEqual(result.returncode, 6)
        self.assertEqual([rule for _, rule in self.rules()], [SDR_RULE])

    def test_open_lid_preferred_mode_and_hdr_layout(self):
        self.connector(hdr=True)
        (self.root / "lid/TEST-ONLY/state").write_text("state: open\n")
        result = self.invoke("dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [HDR_RULE.replace('"0x0"', '"auto-center-up"'), PANEL])
        self.assertEqual(self.rules(), [])

    def test_multiple_externals_use_native_centered_stack(self):
        self.connector("DP-A")
        self.connector("DP-B")
        (self.root / "lid/TEST-ONLY/state").write_text("state: open\n")
        self.snapshots([INTERNAL, dict(EXTERNAL, name="DP-B"), dict(EXTERNAL, name="DP-A")])
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.rules(), [
            [1, SDR_RULE.replace("DP-TEST", "DP-A").replace('"0x0"', '"auto-center-up"')],
            [1, SDR_RULE.replace("DP-TEST", "DP-B").replace('"0x0"', '"auto-center-up"')],
            [1, PANEL],
        ])

    def test_native_preferred_does_not_guess_from_available_modes(self):
        self.connector()
        for modes in [[], ["1280x720@60Hz", "2560x1440@60Hz"],
                      ["2560x1440@60Hz", "1280x720@60Hz"]]:
            with self.subTest(modes=modes):
                (self.root / "rules").write_text("")
                self.snapshots([INTERNAL, dict(EXTERNAL, availableModes=modes)])
                result = self.invoke()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.rules()[0][1], SDR_RULE)

    def test_hdmi_and_usb_c_connector_names_get_same_native_layout(self):
        (self.root / "lid/TEST-ONLY/state").write_text("state: open\n")
        for name in ["HDMI-A-TEST", "DP-TEST-1", "DP-TEST-7"]:
            self.connector(name)
            with self.subTest(name=name):
                (self.root / "rules").write_text("")
                self.snapshots([INTERNAL, dict(EXTERNAL, name=name)])
                result = self.invoke()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual([rule for _, rule in self.rules()], [
                    SDR_RULE.replace("DP-TEST", name).replace('"0x0"', '"auto-center-up"'), PANEL])

    def test_actual_resolution_changes_do_not_freeze_coordinates(self):
        self.connector()
        (self.root / "lid/TEST-ONLY/state").write_text("state: open\n")
        for width, height in [(1280, 720), (2560, 1440), (5120, 1440), (3840, 2160)]:
            with self.subTest(size=(width, height)):
                (self.root / "rules").write_text("")
                self.snapshots([INTERNAL, dict(EXTERNAL, width=width, height=height)])
                result = self.invoke()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual([rule for _, rule in self.rules()], [
                    SDR_RULE.replace('"0x0"', '"auto-center-up"'), PANEL])

    def test_connector_migration_reapplies_without_old_external_name(self):
        self.connector("HDMI-A-TEST")
        self.connector("DP-TEST-7")
        (self.root / "lid/TEST-ONLY/state").write_text("state: open\n")
        self.snapshots([INTERNAL, dict(EXTERNAL, name="HDMI-A-TEST")],
                       [INTERNAL, dict(EXTERNAL, name="DP-TEST-7")])
        (self.root / "events").write_text("monitoradded>>DP-TEST-7\n")
        result = self.invoke("watch")
        self.assertEqual(result.returncode, 0, result.stderr)
        above = SDR_RULE.replace('"0x0"', '"auto-center-up"')
        self.assertEqual(self.rules(), [
            [1, above.replace("DP-TEST", "HDMI-A-TEST")], [1, PANEL],
            [2, above.replace("DP-TEST", "DP-TEST-7")], [2, PANEL]])

    def test_watch_waits_for_initial_output_publication(self):
        self.connector(connected=False)
        result = self.invoke("watch", CONNECT_ON_SLEEP="DP-TEST")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.rules(), [[1, SDR_RULE], [1, DISABLED_PANEL]])

    def test_hotplug_last_external_removal_restores_panel(self):
        self.connector()
        self.snapshots([INTERNAL, EXTERNAL], [INTERNAL, FALLBACK])
        (self.root / "events").write_text("monitorremoved>>DP-TEST\n")
        result = self.invoke("watch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.rules(), [[1, SDR_RULE], [1, DISABLED_PANEL], [2, PANEL]])

    def test_paired_hotplug_events_synchronize_once(self):
        self.snapshots([INTERNAL])
        (self.root / "events").write_text(
            "monitoradded>>DP-TEST\nmonitoraddedv2>>1,DP-TEST,TEST\n"
            "monitorremoved>>DP-TEST\nmonitorremovedv2>>1,DP-TEST,TEST\n")
        result = self.invoke("watch")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.rules(), [[1, PANEL], [2, PANEL], [3, PANEL]])

    def test_config_reload_reapplies_hdr_and_layout(self):
        self.connector(hdr=True)
        (self.root / "lid/TEST-ONLY/state").write_text("state: open\n")
        (self.root / "events").write_text("workspace>>2\nconfigreloaded>>\n")
        result = self.invoke("watch")
        self.assertEqual(result.returncode, 0, result.stderr)
        above = HDR_RULE.replace('"0x0"', '"auto-center-up"')
        self.assertEqual(self.rules(), [[1, above], [1, PANEL], [2, above], [2, PANEL]])

    def test_failed_hotplug_rule_stops_before_panel_and_next_event(self):
        self.connector()
        (self.root / "events").write_text("monitoradded>>DP-TEST\nconfigreloaded>>\n")
        result = self.invoke("watch", FAIL_RULE_QUERY="2", FAIL_RULE_NAME="DP-TEST")
        self.assertEqual(result.returncode, 7)
        self.assertEqual(self.rules(), [[1, SDR_RULE], [1, DISABLED_PANEL], [2, SDR_RULE]])
        self.assertEqual((self.root / "queries").read_text(), "2")

    def test_failed_first_rule_stops_before_other_external(self):
        self.connector("DP-A")
        self.connector("DP-B")
        self.snapshots([INTERNAL, dict(EXTERNAL, name="DP-A"), dict(EXTERNAL, name="DP-B")])
        result = self.invoke(FAIL_RULE_QUERY="1", FAIL_RULE_NAME="DP-A")
        self.assertEqual(result.returncode, 7)
        self.assertEqual(self.rules(), [[1, SDR_RULE.replace("DP-TEST", "DP-A")]])

    def test_zero_exit_rejections_stop_before_panel_and_next_event(self):
        self.connector()
        (self.root / "events").write_text("configreloaded>>\n")
        for reply in ["", "error: rejected", "ok\nerror: rejected", "warning: rejected",
                      "keyword can't work with non-legacy parsers. Use eval."]:
            with self.subTest(reply=reply):
                (self.root / "queries").write_text("0")
                (self.root / "rules").write_text("")
                result = self.invoke("watch", RULE_REPLY=reply)
                self.assertEqual(result.returncode, 1)
                self.assertIn("monitor update rejected", result.stderr)
                self.assertEqual(self.rules(), [[1, SDR_RULE]])
                self.assertEqual((self.root / "queries").read_text(), "1")

    def test_rules_parse_with_native_lua_config(self):
        self.connector(hdr=True)
        for lid in ["open", "closed"]:
            (self.root / "lid/TEST-ONLY/state").write_text(f"state: {lid}\n")
            result = self.invoke("dry-run")
            self.assertEqual(result.returncode, 0, result.stderr)
            config = self.root / "hyprland.lua"
            config.write_text(result.stdout)
            subprocess.run(["Hyprland", "--verify-config", "--config", str(config)],
                           env=dict(self.environment, HOME=str(self.root),
                                    XDG_CONFIG_HOME=str(self.root)),
                           check=True, capture_output=True, text=True, timeout=10)

    def test_output_name_cannot_inject_lua(self):
        name = 'DP-TEST"; error("injected")'
        self.connector(name)
        self.snapshots([INTERNAL, dict(EXTERNAL, name=name)])
        result = self.invoke()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.rules(), [])

    def test_query_failure_propagates(self):
        result = self.invoke(FAIL_QUERY="1")
        self.assertEqual(result.returncode, 6)
        self.assertEqual(self.rules(), [])

    def test_json_and_row_decoding_fail_before_any_rules(self):
        self.connector()
        invalid = ["", "[", "{}", "[] []", "[7]"]
        invalid += [[INTERNAL, dict(EXTERNAL, **fields)] for fields in
                    [{"disabled": "false"}, {"dpmsStatus": None}, {"width": "2560"}, {"height": None}]]
        self.connector("DP-A")
        invalid.append([dict(EXTERNAL, name="DP-A"), dict(EXTERNAL, disabled=None)])
        for snapshot in invalid:
            with self.subTest(snapshot=snapshot):
                self.snapshots(snapshot)
                result = self.invoke()
                self.assertNotEqual(result.returncode, 0)
                self.assertNotEqual(result.stderr, "")
                self.assertEqual(self.rules(), [])

    def test_watch_row_decoding_failure_stops_next_event(self):
        self.connector()
        self.snapshots([INTERNAL, EXTERNAL], [INTERNAL, dict(EXTERNAL, disabled=None)])
        (self.root / "events").write_text("monitoradded>>DP-TEST\nconfigreloaded>>\n")
        result = self.invoke("watch")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotEqual(result.stderr, "")
        self.assertEqual(self.rules(), [[1, SDR_RULE], [1, DISABLED_PANEL]])
        self.assertEqual((self.root / "queries").read_text(), "2")

    def test_edid_failure_is_not_treated_as_sdr(self):
        self.connector(status=9)
        result = self.invoke()
        self.assertEqual(result.returncode, 9)
        self.assertEqual(self.rules(), [])

    def test_disconnected_same_name_connector_is_not_decoded(self):
        self.connector(hdr=True)
        disconnected = self.root / "drm/card0-DP-TEST"
        disconnected.mkdir()
        (disconnected / "status").write_text("disconnected\n")
        (disconnected / "edid").write_text("")
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.rules(), [[1, HDR_RULE], [1, DISABLED_PANEL]])

    def test_lid_read_failure_prevents_rules(self):
        (self.root / "lid/TEST-ONLY/state").write_text("")
        result = self.invoke()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.rules(), [])

    def test_socket_failure_propagates_without_reconnect(self):
        self.snapshots([INTERNAL])
        result = self.invoke("watch", SOCKET_STATUS="8")
        self.assertEqual(result.returncode, 8)
        self.assertEqual((self.root / "queries").read_text(), "0")
        self.assertEqual(self.rules(), [])

    def test_native_socket_refusal_prevents_all_mutations(self):
        (self.root / "bin/socat").unlink()
        result = self.invoke("watch")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.root / "queries").read_text(), "0")
        self.assertEqual(self.rules(), [])

    def test_native_socket_subscription_precedes_initial_sync(self):
        (self.root / "bin/socat").unlink()
        self.snapshots([INTERNAL])
        path = self.root / "runtime/hypr/TEST-ONLY/.socket2.sock"
        path.parent.mkdir(parents=True)
        with socket.socket(socket.AF_UNIX) as server:
            server.bind(str(path))
            server.listen()
            server.settimeout(5)
            with subprocess.Popen(["bash", str(self.script), "watch"], text=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  env=self.environment) as process:
                connection, _ = server.accept()
                with connection:
                    connection.sendall(b"configreloaded>>\n")
                _, stderr = process.communicate(timeout=10)
                self.assertEqual(process.returncode, 0, stderr)
        self.assertEqual(self.rules(), [[1, PANEL], [2, PANEL]])


unittest.main()
