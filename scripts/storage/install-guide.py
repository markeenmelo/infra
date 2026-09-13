from contextlib import contextmanager
import getpass
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import warnings


HOST = r"[a-z][a-z0-9-]*"
FINGERPRINT = r"SHA256:[A-Za-z0-9+/]{43}"
DEVICE = r"/dev/disk/by-(id|path)/[a-zA-Z0-9._:+-]+"


def run(arguments, *, capture=False, environment=None):
    result = subprocess.run(arguments, check=True, text=True,
                            cwd=os.environ["DEVENV_ROOT"], env=environment,
                            stdout=subprocess.PIPE if capture else None)
    return result.stdout.strip() if capture else ""


class Terminal:
    def __init__(self, reader, writer):
        self.reader = reader
        self.writer = writer

    def say(self, text):
        print(text, file=self.writer, flush=True)

    def ask(self, prompt, *, hidden=False):
        if os.tcgetpgrp(self.reader.fileno()) != os.getpgrp():
            raise ValueError("Bring the installer back to the foreground before answering.")
        if hidden:
            with warnings.catch_warnings():
                warnings.simplefilter("error", getpass.GetPassWarning)
                return getpass.getpass(prompt + ": ", stream=self.writer).strip()
        self.writer.write(prompt + ": ")
        self.writer.flush()
        answer = self.reader.readline()
        if not answer:
            raise EOFError
        return answer.strip()

    def review(self, plan):
        environment = dict(os.environ, LESSSECURE="1", LESSSECURE_ALLOW="", LESSHISTFILE="-", LESS="")
        for key in ["LESSOPEN", "LESSCLOSE"]:
            environment.pop(key, None)
        self.say("Opening the disk plan. Read it; press q to return. This does not execute it.")
        subprocess.run(["less", "--", str(plan)], check=True, env=environment,
                       stdin=self.reader, stdout=self.writer, stderr=self.writer)


@contextmanager
def foreground_terminal():
    fd = os.open("/dev/tty", os.O_RDWR | os.O_NOCTTY)
    try:
        if not os.isatty(fd) or os.tcgetpgrp(fd) != os.getpgrp():
            raise ValueError("Run install HOST in a foreground terminal, not a background job.")
        with os.fdopen(os.dup(fd), "r", encoding="utf-8") as reader, \
                os.fdopen(os.dup(fd), "w", encoding="utf-8", buffering=1) as writer:
            yield Terminal(reader, writer)
    finally:
        os.close(fd)


def ask_matching(ui, prompt, pattern, *, default=None):
    while True:
        value = ui.ask(prompt + (f" [{default}]" if default is not None else ""))
        if not value and default is not None:
            value = default
        if re.fullmatch(pattern, value):
            return value
        ui.say("That value has the wrong format. Please try again; Ctrl-C cancels.")


def ask_path(ui, prompt, *, directory=False):
    while True:
        value = ui.ask(prompt + " (path only; input hidden)", hidden=True)
        try:
            path = Path(value).expanduser()
            if value and not any(ord(char) < 32 or ord(char) == 127 for char in value) \
                    and path.is_absolute() and (path.is_dir() if directory else path.is_file()):
                return str(path)
        except (OSError, RuntimeError, ValueError):
            pass
        ui.say("Use an existing absolute path or ~/path; do not paste a key's contents.")


def guide(host, ui):
    if not re.fullmatch(HOST, host):
        raise ValueError("Usage: install HOST")
    if any(key in os.environ for key in ["SSH_PRIVATE_KEY", "SSHPASS", "LOCAL_KEY"]):
        raise ValueError("Remove inherited credential/signing variables before starting.")
    if run(["git", "status", "--porcelain"], capture=True):
        raise ValueError("Commit the reviewed candidate first; do not commit private recovery files.")
    revision = run(["git", "rev-parse", "HEAD"], capture=True)
    ui.say(f"\nInstall {host}\nThis will erase its OS disk, not update a running system. Ctrl-C cancels.")
    ui.say("Checking local ciphertext and looking up the host configuration; no target contact yet.")
    run(["bash", "scripts/secrets/check.sh"])
    report = json.loads(run(["nix", "eval", "--no-update-lock-file", "--json", f".#fleet.{host}"], capture=True))
    if report.get("ready") is not True or report.get("missing") != [] or report.get("failedAssertions") != []:
        raise ValueError("This host is not commissioned or has unresolved checks. Resolve them before installation.")
    device = report.get("osDisk")
    if report.get("storageMode") != "provision" or not isinstance(device, str) \
            or not re.fullmatch(DEVICE, device) or re.search(r"-part[0-9]+$", device):
        raise ValueError("No reviewed whole OS disk is configured for this host.")
    secrets = json.loads(run(["nix", "eval", "--no-update-lock-file", "--json",
                             f".#fleetConfigurations.{host}.config.fleet.secrets"], capture=True))
    age = secrets["ageRecipient"]
    if age is not None and (not isinstance(age, str) or not re.fullmatch(r"age1[a-z0-9]+", age)):
        raise ValueError("The configured age recipient is invalid.")
    if secrets["ageKeyFile"] != (None if age is None else "/persist/var/lib/sops-nix/key.txt"):
        raise ValueError("The configured age path is not supported by installer staging.")
    ui.say(f"\nOS disk: {device}\nSOPS age key: {'not required; do not stage one' if age is None else 'required'}")
    if host == "bastion":
        ui.say("Bastion's tank disks must remain untouched. Verify backups and keep the pool unimported.")
    ui.say("At the live USB console, verify the current address/SSH port and OS disk serial.")
    target = ask_matching(ui, "Live USB address (IPv4/DNS, optionally root@)", r"(?:root@)?[a-zA-Z0-9][a-zA-Z0-9.-]*")
    if not target.startswith("root@"):
        target = "root@" + target
    while True:
        port = int(ask_matching(ui, "Console-verified SSH port", r"[0-9]{1,5}", default="22"))
        if 1 <= port <= 65535:
            break
        ui.say("Choose a port from 1 to 65535.")
    ui.say("Get the USB fingerprint at its console: ssh-keygen -E sha256 -lf /etc/ssh/ssh_host_ed25519_key.pub")
    fingerprint = ask_matching(ui, "Live USB ED25519 fingerprint (SHA256:...)", FINGERPRINT)
    if device.startswith("/dev/disk/by-path/"):
        if host != "racknerd" or not device.startswith("/dev/disk/by-path/pci-"):
            raise ValueError("Only Racknerd has a reviewed PCI/size identity exception.")
        identity = "size:" + ask_matching(ui, "Console-verified whole disk size in bytes", r"[1-9][0-9]*")
    else:
        identity = ask_matching(ui, "Console-verified serial of the displayed OS disk", r"[^\x00-\x1f\x7f]{1,128}")
    key = ask_path(ui, "Private SSH key for logging into the live USB")
    ui.say("Recovery staging must be an owned private directory outside the checkout/store.")
    ui.say("It must contain persist/etc/machine-id and persist/etc/ssh/ssh_host_ed25519_key{,.pub}.")
    if age is not None:
        ui.say("Also include persist/var/lib/sops-nix/key.txt for the configured age recipient.")
    staging = ask_path(ui, "Prepared recovery staging directory", directory=True)
    ui.say("Use independently verified host-labelled recovery records for the next two answers, not the USB or an unreviewed staging bundle.")
    while True:
        machine = ask_matching(ui, f"Preserved {host} machine ID", r"[a-f0-9]{32}")
        if machine != "0" * 32:
            break
        ui.say("The all-zero machine ID is not valid.")
    installed_fingerprint = ask_matching(ui, f"Preserved {host} SSH host fingerprint (not the USB fingerprint)", FINGERPRINT)
    with tempfile.TemporaryDirectory(prefix="fleet-install-guide-", dir="/tmp") as work:
        manifest = Path(work) / "manifest.json"
        with open(manifest, "x", encoding="utf-8", opener=lambda path, flags: os.open(path, flags, 0o600)) as stream:
            json.dump(dict(host=host, machineId=machine, sshHostFingerprint=installed_fingerprint, ageRecipient=age), stream)
        environment = dict(os.environ, FLEET_INSTALL_IDENTITY=key, FLEET_INSTALL_EXTRA_FILES=staging,
                           FLEET_INSTALL_MANIFEST=str(manifest))
        run(["python3", "scripts/storage/check-staging.py", host, json.dumps(age)], environment=environment)
        ui.say("\nBuilding the local disk plan for review; it will not be executed yet.")
        run(["bash", "scripts/fleet/ready.sh", host, "disk-plan"])
        plan = Path(run(["nix", "build", "--no-update-lock-file", "--no-link", "--print-out-paths",
                         f".#nixosConfigurations.{host}.config.system.build.diskoScript"], capture=True))
        if not plan.is_relative_to("/nix/store") or not plan.is_file():
            raise ValueError("The generated disk plan is not a Nix-store file.")
        plan_hash = hashlib.sha256(plan.read_bytes()).hexdigest()
        ui.review(plan)
        if ui.ask("Have you reviewed the full plan, verified backups/recovery, firmware and the isolated OS-only disk boundary? [y/N]").lower() != "y":
            ui.say("Cancelled; installer not started.")
            return 1
        ui.say(f"\nERASE AND REINSTALL\nHost: {host}\nInstaller: {target}:{port}\nOS disk: {device}\nSerial/size: {identity}\nUSB fingerprint: {fingerprint}\nPlan SHA256: {plan_hash}\nNo kexec or automatic reboot.")
        phrase = f"ERASE {host}"
        if ui.ask(f"Type {phrase} to authorize erasing the displayed disk after all checks pass") != phrase:
            ui.say("Cancelled; installer not started.")
            return 1
        if run(["git", "status", "--porcelain"], capture=True) or run(["git", "rev-parse", "HEAD"], capture=True) != revision:
            raise ValueError("The candidate changed during review. Start again with a clean reviewed commit.")
        environment["DEVENV_TASK_INPUT"] = json.dumps(dict(host=host, target=target, port=port, device=device,
            identity=identity, fingerprint=fingerprint, planHash=plan_hash,
            confirm=f"ERASE {host} {target} {device} {identity}"))
        ui.say("Running the shared full preflight and guarded installer. This may take a while; no checks are skipped.")
        run(["bash", "scripts/devenv/host-install.sh"], environment=environment)
    return 0


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            raise ValueError("Usage: install HOST")
        with foreground_terminal() as terminal:
            sys.exit(guide(sys.argv[1], terminal))
    except (KeyboardInterrupt, EOFError):
        sys.exit("Interrupted. If installation had already started, inspect the target before retrying.")
    except subprocess.CalledProcessError as error:
        sys.exit(f"A required step failed (exit {error.returncode}); stopped without bypassing it.")
    except (OSError, KeyError, TypeError, getpass.GetPassWarning):
        sys.exit("Cannot continue: check the foreground terminal, private path permissions and required tools. Details withheld.")
    except ValueError as error:
        sys.exit(str(error))
