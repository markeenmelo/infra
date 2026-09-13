import json
import os
from pathlib import Path
import re
import sys

try:
    data = json.loads(os.environ.get("DEVENV_TASK_INPUT", "{}"))
    assert set(data) == {"name", "system", "track", "group"}
    name = data["name"]
    assert isinstance(name, str) and re.fullmatch(r"[a-z][a-z0-9-]{0,62}", name)
    assert not name.endswith("-") and name not in {"servers", "workstations"}
    assert data["system"] == "x86_64-linux"
    assert data["track"] in {"stable", "unstable"}
    assert data["group"] in {"servers", "workstations"}
except (ValueError, TypeError, KeyError, AssertionError):
    sys.exit("host:create requires name, system=x86_64-linux, track=stable|unstable and group=servers|workstations")

root = Path(os.environ["DEVENV_ROOT"]).resolve()
hosts = root / "modules/hosts"
assert hosts.is_dir() and not hosts.is_symlink(), "Missing real modules/hosts directory"
destination = hosts / name
if destination.exists() or destination.is_symlink():
    sys.exit("Refusing to overwrite an existing host path")
capabilities = ["headless", "persistence", "access", "deploy"]
capabilities += ["server"] if data["group"] == "servers" else ["workstation"]
quoted = " ".join(json.dumps(value) for value in capabilities)
files = {
    "host.nix": f'''{{
  fleet.hosts.{name} = {{
    system = "x86_64-linux";
    track = "{data['track']}";
    ready = false;
    capabilities = [ {quoted} ];
  }};
}}
''',
    "hardware.nix": f'''{{
  fleet.hosts.{name}.module.fleet.installation = {{
    stateVersion = null;
    hardwareReviewed = false;
    networkReviewed = false;
  }};
}}
''',
    "disko.nix": f'''{{ inputs, ... }}:
{{
  fleet.hosts.{name}.module = {{ config, lib, pkgs, ... }}: {{
    imports = [ inputs.disko.nixosModules.disko ];
    fleet.installation = {{
      osDevice = null;
      storageReviewed = false;
    }};
    fleet.bootstrap.missing = [ "Define and review {name}'s OS-only disko layout, firmware, backups and state recovery." ];
    system.build = lib.genAttrs (
      builtins.attrNames (config.disko.devices._scripts {{ inherit pkgs; }})
      ++ [ "disko" "diskoNoDeps" "installTest" "vmWithDisko" "diskoImages" "diskoImagesScript" ]
    ) (alias: lib.mkForce (throw "{name}: ${{alias}} is unavailable for an incomplete scaffold."));
  }};
}}
''',
}
destination.mkdir(mode=0o755)
for filename, text in files.items():
    with (destination / filename).open("x") as output:
        output.write(text)
print(f"Created untracked, unready scaffold: modules/hosts/{name}/")
print(f"Complete real hardware/storage/access facts; add {name} to modules/deploy.nix group {data['group']} and the independent track/host oracles.")
print("Review all feature predicates/composition fixtures before staging. No staging, evaluation, installation, credentials or remote operations performed.")
