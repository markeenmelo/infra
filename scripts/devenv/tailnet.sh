#!/usr/bin/env bash
set +x
set -euo pipefail

die() { printf '%s\n' "$*" >&2; exit 1; }
input=${DEVENV_TASK_INPUT:-'{}'}
[[ $# == 0 ]] || die 'Use tailnet:deploy --input action=plan|apply [--input plan=/ABSOLUTE/PRIVATE/SAVED_PLAN].'
jq -e '
  type == "object" and
  (if .action == "plan" then keys == ["action"]
   elif .action == "apply" then
     keys == ["action", "plan"] and (.plan | type == "string" and startswith("/"))
   else false end)
' <<<"$input" >/dev/null || die 'Require action=plan, or action=apply with an absolute saved plan; no other inputs.'

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
[[ -z $(git status --porcelain --untracked-files=all) ]] \
  || die 'Tailnet operations require a clean, reviewed, committed tree.'

exec python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import urllib.error
import urllib.parse
import urllib.request


def fail(message):
    raise SystemExit(message)


def reject_auto_vars():
    for path in (repo / 'opentofu/tailscale').iterdir():
        if (path.name in ('terraform.tfvars', 'terraform.tfvars.json')
                or path.name.endswith(('.auto.tfvars', '.auto.tfvars.json'))):
            fail(f'Automatic OpenTofu variable file is forbidden: {path.name!r}. '
                 'Review and move it outside opentofu/tailscale before retrying.')


def private(path, directory=False):
    info = path.lstat()
    kind = stat.S_ISDIR if directory else stat.S_ISREG
    mode = 0o700 if directory else 0o600
    if (not kind(info.st_mode) or info.st_uid != os.getuid()
            or stat.S_IMODE(info.st_mode) != mode
            or (not directory and info.st_nlink != 1)):
        fail(f'Unsafe runtime path: {path}')


os.umask(0o077)
repo = Path.cwd()
reject_auto_vars()
revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
inputs = json.loads(os.environ['DEVENV_TASK_INPUT'])
root = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'infra/tailscale'
if not root.is_absolute() or root != root.resolve() or root.is_relative_to(repo) or root.is_relative_to('/nix/store'):
    fail('State must use an absolute, non-symlink path outside the checkout and Nix store.')
for parent in reversed([root, *root.parents]):
    if not parent.exists():
        parent.mkdir(mode=0o700)
    info = parent.lstat()
    if (not stat.S_ISDIR(info.st_mode) or info.st_uid not in (0, os.getuid())
            or stat.S_IMODE(info.st_mode) & 0o022):
        fail(f'Unsafe state ancestry: {parent}')
private(root, directory=True)
for path in [root / 'data', root / 'plans']:
    path.mkdir(mode=0o700, exist_ok=True)
    private(path, directory=True)
for path in root.glob('terraform.tfstate*'):
    private(path)

plan = None
if inputs['action'] == 'apply':
    plan = Path(inputs['plan'])
    if plan != plan.resolve() or plan.name != 'plan.tfplan' or plan.parent.parent != root / 'plans':
        fail('Select plan.tfplan from a task-created private plan directory.')
    private(plan.parent, directory=True)
    private(plan)
    manifest = plan.parent / 'revision.json'
    private(manifest)
    recorded = json.loads(manifest.read_text())
    if recorded != {'revision': revision, 'sha256': hashlib.sha256(plan.read_bytes()).hexdigest()}:
        fail('Saved plan or source revision mismatch; review and generate a new plan.')
    if (plan.parent / 'attempted').exists():
        fail('This plan was already attempted. Inspect state and re-plan; never blindly retry.')

# Ignore ambient CLI flags, encryption overrides, credentials and debug logging.
env = {k: v for k, v in os.environ.items() if not k.startswith(('TF_', 'TOFU_', 'TAILSCALE_'))}
env.update(TF_DATA_DIR=str(root / 'data'), TF_WORKSPACE='default',
           TF_CLI_CONFIG_FILE='/dev/null', TF_INPUT='0', TF_IN_AUTOMATION='1')
secrets = json.loads(subprocess.check_output(
    ['sops', '--decrypt', '--output-type', 'json', 'secrets/tailscale/operator.yaml'], env=env))
fields = {'TAILSCALE_OAUTH_CLIENT_ID', 'TAILSCALE_OAUTH_CLIENT_SECRET',
          'TAILSCALE_TAILNET', 'TF_VAR_state_passphrase'}
if set(secrets) != fields or any(not isinstance(v, str) or not v for v in secrets.values()):
    fail('Operator source must contain exactly the four nonempty credential fields.')
env['TF_VAR_state_passphrase'] = secrets['TF_VAR_state_passphrase']
env['TAILSCALE_TAILNET'] = secrets['TAILSCALE_TAILNET']


def request(path, data, headers=None):
    req = urllib.request.Request('https://api.tailscale.com/api/v2/' + path,
                                 data=data, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        fail(f'Tailscale request failed (HTTP {error.code}); no automatic retry.')
    except (urllib.error.URLError, TimeoutError, ValueError):
        fail('Tailscale request failed or returned invalid JSON; no automatic retry.')


def token(scopes):
    result = request('oauth/token', urllib.parse.urlencode({
        'grant_type': 'client_credentials', 'client_id': secrets['TAILSCALE_OAUTH_CLIENT_ID'],
        'client_secret': secrets['TAILSCALE_OAUTH_CLIENT_SECRET'], 'scope': scopes,
    }).encode())
    if not isinstance(result.get('access_token'), str) or not result['access_token']:
        fail('OAuth response has no access token.')
    return result['access_token']


read_scopes = ('policy_file:read devices:core:read devices:posture_attributes:read '
               'dns:read feature_settings:read auth_keys:read')
read_token = token(read_scopes)
tailnet = urllib.parse.quote(secrets['TAILSCALE_TAILNET'], safe='')
for endpoint, expected in [('nameservers', {'dns': []}), ('split-dns', {})]:
    if request(f'tailnet/{tailnet}/dns/{endpoint}', None,
               {'Authorization': 'Bearer ' + read_token}) != expected:
        fail(f'DNS {endpoint} drifted or returned an unexpected response; stop and review.')
result = request(f'tailnet/{tailnet}/acl/validate',
                 (repo / 'assets/tailscale/policy.hujson').read_bytes(),
                 {'Authorization': 'Bearer ' + read_token, 'Content-Type': 'application/hujson'})
if result != {}:
    fail('Policy validation rejected the file or returned an unexpected response; stop and inspect the native tests.')
print('Native policy validation passed.', flush=True)
env['TAILSCALE_API_KEY'] = read_token


def tofu(*args):
    reject_auto_vars()
    subprocess.run(('tofu', '-chdir=opentofu/tailscale', *args), check=True, env=env)


tofu('init', '-input=false', '-lockfile=readonly',
     '-backend-config=path=' + str(root / 'terraform.tfstate'),
     '-backend-config=workspace_dir=' + str(root / 'workspaces'))
tofu('validate')
if subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=all']) or revision != subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip():
    fail('Source changed during validation; stop and review.')
if inputs['action'] == 'plan':
    folder = Path(tempfile.mkdtemp(prefix='review-', dir=root / 'plans'))
    plan = folder / 'plan.tfplan'
    tofu('plan', '-input=false', '-out=' + str(plan))
    if subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=all']) or revision != subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip():
        fail('Source changed during planning; this plan is not approved for use.')
    (folder / 'revision.json').write_text(json.dumps({
        'revision': revision, 'sha256': hashlib.sha256(plan.read_bytes()).hexdigest(),
    }) + '\n')
    print(f'Review the encrypted saved plan: {plan}')
else:
    env['TAILSCALE_API_KEY'] = token('policy_file devices:core devices:posture_attributes dns feature_settings auth_keys')
    (plan.parent / 'attempted').touch(mode=0o600, exist_ok=False)
    tofu('apply', '-input=false', str(plan))
PY
