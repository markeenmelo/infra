{
  lib,
  config,
  pkgs,
  ...
}:
let
  # Single source for the ciphertext/public-metadata guard, inlined into both
  # secret tasks below. Never decrypts, imports identities or prints values;
  # catches accidental plaintext and recipient drift, not cryptographic validity.
  checkSecretPayloads = ''
    check_secret_payloads() {
      local rules file
      rules=$(yq -o=json '.' .sops.yaml 2>/dev/null) || {
        echo 'Cannot parse .sops.yaml (content withheld).' >&2
        return 1
      }
      shopt -s nullglob
      local -a files
      files=(secrets/hosts/*.yaml secrets/shared/*.yaml)
      if ((''${#files[@]} == 0)); then
        echo 'No encrypted credential files found.' >&2
        return 1
      fi
      for file in "''${files[@]}"; do
        # JSON conversion discards duplicate keys and overridden YAML merge values.
        # Reject both in the YAML tree before inspecting the converted payload.
        if ! yq -e '([.. | select(tag == "!!map") | keys | select(length != (unique | length))] + [... | select(tag == "!!merge")]) | length == 0' "$file" >/dev/null 2>&1; then
          printf 'Ambiguous or invalid YAML: %s (content withheld).\n' "$file" >&2
          return 1
        fi
        if ! yq -o=json '.' "$file" 2>/dev/null | jq -e -s --arg file "$file" --argjson rules "$rules" '
          def encrypted:
            type == "string" and test("^ENC\\[AES256_GCM,data:[A-Za-z0-9+/=]+,iv:[A-Za-z0-9+/=]+,tag:[A-Za-z0-9+/=]+,type:str\\]$");
          if length != 1 then error("Expected one YAML document") else .[0] end
          | . as $doc
          | [$rules.creation_rules[] | . as $rule | select($file | test($rule.path_regex))] as $matching
          | type == "object"
            and ($matching | length == 1)
            and ($matching[0].key_groups | length == 1)
            and ($matching[0].key_groups[0] | keys == ["age"])
            and (if $file == "secrets/shared/marcos-password.yaml"
                 then (keys | sort) == ["marcos-password-hash", "sops"] else true end)
            and ([del(.sops) | .. | scalars] | length > 0 and all(.[]; encrypted))
            and (.sops.mac | encrypted)
            and (.sops.age | length > 0)
            and (all(.sops.age[];
              (keys | sort == ["enc", "recipient"])
              and (.recipient | test("^age1[a-z0-9]+$"))
              and (.enc | startswith("-----BEGIN AGE ENCRYPTED FILE-----") and contains("-----END AGE ENCRYPTED FILE-----"))))
            and (([.sops.age[].recipient] | sort) == ($matching[0].key_groups[0].age | sort))
            and (["kms", "gcp_kms", "azure_kv", "hc_vault", "pgp"] | all(.[]; ($doc.sops[.] // []) == []))
            and (.sops | keys - ["age", "mac", "version", "lastmodified", "unencrypted_suffix", "kms", "gcp_kms", "azure_kv", "hc_vault", "pgp"] | length == 0)
        ' >/dev/null 2>&1; then
          printf 'Encrypted payload/recipient check failed: %s (content withheld).\n' "$file" >&2
          return 1
        fi
      done
      printf 'Encrypted credential payloads and recipient rules checked (%s files); no decryption.\n' "''${#files[@]}"
    }
  '';
in
{
  # Native development entry point; production remains in flake.nix/modules/.
  # Do not resolve secrets in Nix, shell hooks, tasks or direnv's cached environment.
  stdenv = pkgs.stdenvNoCC;
  cachix.enable = false;
  dotenv.enable = false;
  devenv.warnOnNewVersion = false;

  packages = [
    pkgs.devenv
    pkgs.nix
    pkgs.nixfmt-tree
    pkgs.nixfmt
    pkgs.statix
    pkgs.deadnix
    pkgs.nixd
    pkgs.jq
    pkgs.git
    pkgs.openssh
    pkgs.shellcheck
    pkgs.bash-language-server
    pkgs.python3
    pkgs.sops
    pkgs.age
    pkgs.yq-go
  ];

  languages.opentofu = {
    enable = true;
    # Same unstable package/provider as checks.x86_64-linux.tailscale-offline.
    package = pkgs.opentofu.withPlugins (providers: [ providers.tailscale_tailscale ]);
    lsp.package = pkgs.tofu-ls;
  };

  # One formatting declaration replaces the duplicated fmt/lint/fixture stacks.
  # nixfmt, deadnix and ShellCheck report through treefmt; report-only statix
  # stays in repo:lint because treefmt can only run statix's fixing mode.
  treefmt = {
    enable = true;
    config.programs = {
      nixfmt.enable = true;
      deadnix.enable = true;
      shellcheck.enable = true;
      terraform.enable = true; # OpenTofu formatting; provider plugins are irrelevant to fmt.
    };
  };

  tasks."devenv:treefmt:run".before = lib.mkForce [ ];

  # Optional local hooks, not another canonical gate and never a live operation.
  # Opt in with `devenv --profile hooks shell`; ordinary shell entry installs none.
  profiles.hooks.module.git-hooks.hooks = {
    treefmt.enable = true;
    statix.enable = true;
    encrypted-secrets = {
      enable = true;
      name = "Encrypted payloads and public recipients (no decryption)";
      entry = "devenv tasks run repo:secret-check";
      files = "^(secrets/|\\.sops\\.yaml$)";
      pass_filenames = false;
    };
  };

  tasks = {
    "repo:fmt".exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      treefmt
    '';
    "repo:format-check".exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      treefmt --ci
    '';
    # Report-only linter; the fixing/checking formatters live in treefmt above.
    "repo:lint".exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      statix check .
    '';
    "repo:secret-check".exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      ${checkSecretPayloads}
      check_secret_payloads
    '';
    "repo:secret-check-tests".exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      # Local throwaway ciphertext copies + obvious dummy strings, never decryption.
      ${checkSecretPayloads}
      work=$(mktemp -d)
      trap 'rm -rf "$work"' EXIT
      mkdir -p "$work/secrets/hosts" "$work/secrets/shared"
      cp .sops.yaml "$work/.sops.yaml"
      file="$work/secrets/hosts/thinkpad.yaml"
      cp secrets/hosts/thinkpad.yaml "$file"
      shared="$work/secrets/shared/marcos-password.yaml"
      cp secrets/shared/marcos-password.yaml "$shared"
      # Store inputs are read-only; only these disposable test copies may be mutated.
      chmod u+w "$file" "$shared"
      (cd "$work" && check_secret_payloads)
      repo=$PWD
      for variant in plaintext recipient missing-mac unsupported-backend invalid-yaml multiple-documents duplicate-key merge-key nested-merge \
        shared-plaintext shared-extra-key; do
        cp "$repo/secrets/hosts/thinkpad.yaml" "$file"
        cp "$repo/secrets/shared/marcos-password.yaml" "$shared"
        case "$variant" in
          plaintext) yq -i '."marcos-password-hash" = "TEST-ONLY-NOT-A-HASH"' "$file" ;;
          recipient) yq -i '.sops.age[0].recipient = .sops.age[1].recipient' "$file" ;;
          missing-mac) yq -i 'del(.sops.mac)' "$file" ;;
          unsupported-backend) yq -i '.sops.kms = [{"arn": "TEST-ONLY-NOT-A-KEY"}]' "$file" ;;
          invalid-yaml) printf 'unclosed: [\n' > "$file" ;;
          shared-plaintext) yq -i '."marcos-password-hash" = "TEST-ONLY-NOT-A-HASH"' "$shared" ;;
          shared-extra-key) yq -i '."wifi-psk" = ."marcos-password-hash"' "$shared" ;;
          multiple-documents)
            {
              printf 'plain: TEST-ONLY-NOT-A-SECRET\n---\n'
              dd if="$repo/secrets/hosts/thinkpad.yaml" status=none
            } > "$file"
            ;;
          duplicate-key)
            {
              printf 'marcos-password-hash: TEST-ONLY-NOT-A-HASH\n'
              dd if="$repo/secrets/hosts/thinkpad.yaml" status=none
            } > "$file"
            ;;
          merge-key)
            {
              printf '<<: {marcos-password-hash: TEST-ONLY-NOT-A-HASH}\n'
              dd if="$repo/secrets/hosts/thinkpad.yaml" status=none
            } > "$file"
            ;;
          nested-merge)
            # A nested merge's plaintext MAC would disappear during JSON conversion.
            awk '{ print } /^sops:$/ { print "    <<: {mac: TEST-ONLY-NOT-A-SECRET}" }' \
              "$repo/secrets/hosts/thinkpad.yaml" > "$file"
            ;;
        esac
        if (cd "$work" && check_secret_payloads) >"$work/result" 2>&1; then
          printf 'ERROR: secret guard accepted %s.\n' "$variant" >&2
          exit 1
        fi
        grep -q 'content withheld' "$work/result"
        if grep -q 'TEST-ONLY-NOT-' "$work/result"; then
          printf 'ERROR: secret guard printed dummy payload for %s.\n' "$variant" >&2
          exit 1
        fi
        printf 'Secret guard rejected %s; values withheld.\n' "$variant"
      done
    '';
    # Native task-graph contract: exact inventory, gate composition, uncached
    # safety gates, shell-entry purity, lock parity and OpenTofu wrapper parity.
    # Evaluating any flake attr copies this tracked tree (secrets/ included)
    # into the world-readable store, so the parity eval below must never race
    # the ciphertext guard: the guard completes first.
    "repo:tooling-check" = {
      after = [ "repo:secret-check" ];
      exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"
        tasks=$DEVENV_TASK_FILE

        expect() {
          local description=$1
          shift
          jq -e "$*" "$tasks" > /dev/null || { printf 'Native task contract violated: %s\n' "$description" >&2; exit 1; }
        }

        expect 'an acyclic task graph' '
          # Kahn elimination over both dependency directions: an edge X->Y means
          # "X must run before Y" (Y.after contains X, or X.before contains Y).
          # A cycle is any node set that never runs out of prerequisite-free
          # nodes; the existence check below owns unknown references.
          def kahn($nodes; $edges):
            [$nodes[] | select(. as $n | $edges | all(.[1] != $n))] as $ready
            | if ($nodes | length) == 0 then true
              elif ($ready | length) == 0 then false
              else
                kahn(
                  [$nodes[] | select(. as $n | ($ready | index($n)) | not)];
                  [$edges[] | select(.[0] as $from | ($ready | index($from)) | not)]
                )
              end;
          . as $t
          | [$t[].name] as $nodes
          | [ $t[] as $n
              | ((($n.after // [])[] | [., $n.name]), (($n.before // [])[] | [$n.name, .]))
              | select((.[0] as $a | $nodes | index($a) != null) and (.[1] as $b | $nodes | index($b) != null))
            ] as $edges
          | kahn($nodes; $edges)
        '

        expect 'the exact repo task inventory' '
          [ .[] | select(.name | startswith("repo:")) | .name ] | sort == [
            "repo:check",
            "repo:check-full",
            "repo:evaluate",
            "repo:fmt",
            "repo:format-check",
            "repo:inventory",
            "repo:lint",
            "repo:revisions",
            "repo:secret-check",
            "repo:secret-check-tests",
            "repo:tailscale-check",
            "repo:tailscale-inventory",
            "repo:tooling-check"
          ]
        '

        expect 'the isolated explicit single-host deployment task' '
          [ .[] | select(.name | startswith("deploy:"))
            | {name, after, before, input, status, exec_if_modified, show_output} ] == [
            {
              name: "deploy:host",
              after: [],
              before: [],
              input: {confirm: null, host: null, mode: null},
              status: null,
              exec_if_modified: [],
              show_output: true
            }
          ]
        '

        expect 'every dependency to reference an existing task' '
          . as $t
          | all($t[]; ((.after // []) + (.before // []))
            | all(. as $d | any($t[]; .name == $d)))
        '

        expect 'the fast gate to compose only the cheap checks' '
          [ .[] | select(.name == "repo:check") | .after[] ] | sort == [
            "repo:format-check",
            "repo:lint",
            "repo:secret-check",
            "repo:tooling-check"
          ]
        '

        # devenv serializes exec into a store command script; inspect its text.
        fast_command=$(jq -r '.[] | select(.name == "repo:check") | .command' "$tasks")
        full_command=$(jq -r '.[] | select(.name == "repo:check-full") | .command' "$tasks")
        grep -q 'flake check' "$full_command" \
          || { echo 'Native task contract violated: repo:check-full lost the full flake check.' >&2; exit 1; }
        if grep -q 'flake check' "$fast_command"; then
          echo 'Native task contract violated: the fast gate must not run the full flake check.' >&2
          exit 1
        fi

        # Evaluating or building this path flake copies the tracked tree
        # (secrets/ included) into the world-readable store before evaluation
        # even starts, so every such task must wait for the ciphertext guard
        # instead of racing it as a sibling dependency.
        evaluators=$(jq -r '.[] | select(.command != null and .name != "deploy:host") | "\(.name)\t\(.command)"' "$tasks" \
          | while IFS=$'\t' read -r task_name command; do
              grep -Eq 'nix (eval|build|flake check)' "$command" && printf '%s\n' "$task_name"
            done | jq -R -s 'split("\n") | map(select(length > 0))')
        [[ $(jq 'length' <<<"$evaluators") -gt 0 ]] \
          || { echo 'Native task contract violated: no flake-evaluating task found; command inspection is stale.' >&2; exit 1; }
        jq -e --argjson evaluators "$evaluators" "
          def closure(\$t; \$names):
            ([\$names[] as \$n | (\$t[] | select(.name == \$n) | .after[])] | unique) as \$next
            | ((\$names + \$next) | unique) as \$all
            | if (\$next - \$names | length) == 0 then \$all else closure(\$t; \$all) end;
          . as \$t
          | all(\$evaluators[]; . as \$n | closure(\$t; [\$n]) | index(\"repo:secret-check\") != null)
        " "$tasks" > /dev/null \
          || { echo 'Native task contract violated: ciphertext verification must precede every flake evaluation.' >&2; exit 1; }

        expect 'the full gate to close over every required safety gate' '
          def closure($t; $names):
            ([$names[] as $n | ($t[] | select(.name == $n) | .after[])] | unique) as $next
            | (($names + $next) | unique) as $all
            | if ($next - $names | length) == 0 then $all else closure($t; $all) end;
          closure(. ; ["repo:check-full"]) as $c
          | all(
              "repo:evaluate",
              "repo:secret-check",
              "repo:secret-check-tests",
              "repo:format-check",
              "repo:lint",
              "repo:tooling-check"
            ; $c | index(.))
        '

        expect 'every safety gate to stay uncached' '
          [.[]
            | select(.name as $n
              | ["repo:check", "repo:check-full", "repo:evaluate", "repo:format-check", "repo:lint",
                 "repo:secret-check", "repo:secret-check-tests", "repo:tooling-check"]
              | index($n))]
          | all(.status == null and ((.exec_if_modified // []) | length == 0))
        '

        expect 'shell entry to run no repository, deployment or treefmt operation' '
          ([.[] | select((.before // []) | index("devenv:enterShell")) | .name]
            + [.[] | select(.name == "devenv:enterShell") | (.after // [])[]])
          | all(test("^(repo:|deploy:|devenv:treefmt)") | not)
        '

        deploy_command=$(jq -r '.[] | select(.name == "deploy:host") | .command' "$tasks")
        for requirement in \
          'devenv --no-tui tasks run repo:check-full --mode before' \
          'bash modules/fleet/ready.sh "$host" deploy' \
          'nix key convert-secret-to-public' \
          '.interactiveSudo' \
          'LOCAL_KEY' \
          'deploy ".#$host"' \
          '--interactive' \
          '--checksigs' \
          '--no-update-lock-file'; do
          grep -Fq -- "$requirement" "$deploy_command" \
            || { printf 'Native task contract violated: deploy:host lacks %s.\n' "$requirement" >&2; exit 1; }
        done
        if grep -Eq -- '--(skip-checks|dry-activate)|--(auto|magic)-rollback[ =]+false' "$deploy_command"; then
          echo 'Native task contract violated: deploy:host weakens checks or rollback.' >&2
          exit 1
        fi
        full_line=$(grep -nF 'devenv --no-tui tasks run repo:check-full --mode before' "$deploy_command" | cut -d: -f1)
        ready_line=$(grep -nF 'bash modules/fleet/ready.sh "$host" deploy' "$deploy_command" | cut -d: -f1)
        deploy_line=$(grep -nF 'exec deploy ".#$host"' "$deploy_command" | cut -d: -f1)
        [[ $full_line -lt $ready_line && $ready_line -lt $deploy_line ]] \
          || { echo 'Native task contract violated: deploy:host preflight order changed.' >&2; exit 1; }

        jq -e --slurpfile flake flake.lock \
          '.nodes.nixpkgs.locked == $flake[0].nodes.nixpkgs.locked' devenv.lock > /dev/null \
          || { echo 'Development/flake unstable pins differ.' >&2; exit 1; }
        jq -e '.nodes.devenv.original == {owner: "cachix", repo: "devenv", type: "github"}' devenv.lock > /dev/null \
          || { echo 'Keep the devenv source unversioned; revisions belong in devenv.lock.' >&2; exit 1; }

        # Catch divergence in the duplicated one-line native OpenTofu package selection.
        packaged=$(nix eval --no-update-lock-file --raw .#packages.x86_64-linux.tailscale-tofu)
        tofu=$(command -v tofu)
        [[ $tofu != null ]] || { echo 'OpenTofu is missing from the native environment.' >&2; exit 1; }
        [[ $(readlink -f "$tofu") == "$packaged/bin/tofu" ]] \
          || { echo 'Use the exact checked OpenTofu/provider wrapper.' >&2; exit 1; }
        echo 'Native task graph, uncached safety gates, unstable lock and OpenTofu/provider parity passed.'
      '';
    };
    "repo:evaluate" = {
      # Serialize Nix evaluations to avoid competing for the same eval-cache DB.
      after = [
        "repo:secret-check"
        "repo:tooling-check"
      ];
      showOutput = true;
      exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"
        nix eval --no-update-lock-file --json .#validation | jq '{hosts: (.hosts | map_values({track, revision, ready, missing, components})), fixtures, compositions, storageLayouts, sops, desktop, wifi, tailscale}'
      '';
    };
    "repo:check" = {
      description = "Fast inner gate for iteration; the canonical gate is repo:check-full";
      after = [
        "repo:format-check"
        "repo:lint"
        "repo:secret-check"
        "repo:tooling-check"
      ];
      showOutput = true;
      exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"
        # Cheap whole-fleet smoke: real host reports still evaluate; no fixtures.
        nix eval --no-update-lock-file --json .#fleet \
          | jq '{hosts: (map_values({track, revision, ready, missing}))}'
      '';
    };
    "repo:check-full" = {
      description = "Canonical non-destructive gate; no credentials, target contact or activation";
      after = [
        "repo:check"
        "repo:evaluate"
        "repo:secret-check-tests"
      ];
      showOutput = true;
      exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"
        nix flake check --no-update-lock-file -L
      '';
    };
    # Standalone fleet evaluation must not bypass the ciphertext guard either.
    "repo:inventory" = {
      after = [ "repo:secret-check" ];
      showOutput = true;
      exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"
        nix eval --no-update-lock-file --json .#fleet | jq .
      '';
    };
    "repo:tailscale-inventory" = {
      after = [ "repo:secret-check" ];
      showOutput = true;
      exec = ''
        set -euo pipefail
        cd "$DEVENV_ROOT"
        nix eval --no-update-lock-file --json .#tailscalePlan | jq .
      '';
    };
    "repo:tailscale-check".exec = ''
      cd "$DEVENV_ROOT"
      bash modules/tailscale/check-tailscale.sh
    '';
    "repo:revisions" = {
      showOutput = true;
      exec = ''
        cd "$DEVENV_ROOT"
        jq '.nodes | with_entries(select(.value.locked)) | map_values(.locked | {rev, narHash, url})' flake.lock devenv.lock
      '';
    };
    # Explicit operator-selected exception: a disconnected, uncached live task.
    # Inputs are public selectors only; signer paths stay in LOCAL_KEY and sudo
    # is read by deploy-rs from the private controlling terminal.
    "deploy:host" = {
      description = "LIVE: validate and deploy exactly one commissioned host";
      input = {
        host = null;
        mode = null;
        confirm = null;
      };
      showOutput = true;
      exec = ''
        set -euo pipefail
        umask 077
        cd "$DEVENV_ROOT"

        refuse() {
          printf 'Refusing deploy:host: %s\n' "$1" >&2
          exit 1
        }

        task_input=''${DEVENV_TASK_INPUT-}
        [[ -n $task_input ]] || task_input='{}'
        jq -e 'keys | sort == ["confirm", "host", "mode"]' <<<"$task_input" >/dev/null \
          || refuse 'inputs must be exactly host, mode and confirm.'
        jq -e '.host | type == "string"' <<<"$task_input" >/dev/null \
          || refuse 'supply --input host=HOST.'
        jq -e '.mode | type == "string"' <<<"$task_input" >/dev/null \
          || refuse 'supply --input mode=boot|switch.'
        jq -e '.confirm | type == "string"' <<<"$task_input" >/dev/null \
          || refuse 'supply the exact confirmation input.'
        host=$(jq -r '.host' <<<"$task_input")
        mode=$(jq -r '.mode' <<<"$task_input")
        confirm=$(jq -r '.confirm' <<<"$task_input")

        [[ $host =~ ^[a-z][a-z0-9-]*$ ]] || refuse 'host has invalid syntax.'
        [[ $mode == boot || $mode == switch ]] || refuse 'mode must be boot or switch.'
        [[ $confirm == "deploy:$host:$mode" ]] \
          || refuse "confirmation must equal deploy:$host:$mode."
        [[ -n ''${LOCAL_KEY:-} ]] || refuse "set LOCAL_KEY to this host's existing private signing-key path."
        [[ -f $LOCAL_KEY && -r $LOCAL_KEY ]] || refuse 'LOCAL_KEY must be a readable regular file.'
        { true </dev/tty; } 2>/dev/null \
          || refuse 'run from a private foreground terminal; CI/background deployment is disabled.'

        # Keep the live task disconnected from the DAG: selecting repo:* in any
        # execution mode cannot pull in deployment. Run the full gate explicitly.
        devenv --no-tui tasks run repo:check-full --mode before
        bash modules/fleet/ready.sh "$host" deploy

        plan=$(nix eval --no-update-lock-file --json ".#deploymentPlan.$host")
        [[ $(jq -r '.transport' <<<"$plan") == signed ]] \
          || refuse 'deploy:host currently permits only signed transport.'
        [[ $(jq -r '.interactiveSudo' <<<"$plan") == true ]] \
          || refuse 'deploy:host requires interactive password sudo.'
        ssh_port=$(jq -r '.sshPort' <<<"$plan")
        [[ $ssh_port =~ ^[0-9]+$ ]] || refuse 'deployment SSH port is invalid.'

        signer_public=$(nix key convert-secret-to-public <"$LOCAL_KEY") \
          || refuse 'LOCAL_KEY is not a valid Nix signing key.'
        trusted_public=$(nix eval --no-update-lock-file --json \
          ".#nixosConfigurations.$host.config.nix.settings.trusted-public-keys")
        jq -e --arg signer "$signer_public" 'index($signer) != null' <<<"$trusted_public" >/dev/null \
          || refuse "LOCAL_KEY does not match this host's configured public signing trust."

        ssh_options="-p $ssh_port -o StrictHostKeyChecking=yes -o UpdateHostKeys=no -o IdentityAgent=none -o IdentitiesOnly=yes -o ForwardAgent=no -o ClearAllForwardings=yes -o ConnectTimeout=15 -o ServerAliveInterval=10 -o ServerAliveCountMax=3"
        mode_args=()
        [[ $mode == switch ]] || mode_args+=(--boot)
        printf 'AUTHORIZED LIVE DEPLOYMENT: host=%s mode=%s; rollback remains enabled.\n' "$host" "$mode" >&2
        exec deploy ".#$host" "''${mode_args[@]}" --interactive --checksigs \
          --ssh-opts "$ssh_options" -- --no-update-lock-file
      '';
    };
  };

  # The live deploy:host task is an explicit isolated exception. It has no DAG
  # edges, so selecting repo:* (even in all mode) cannot deploy. Other credential-
  # bearing operations remain scripts and no shell-entry hook performs live work.
  scripts = {
    ready.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      exec bash modules/fleet/ready.sh "$@"
    '';
    build.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      [[ $# == 1 ]] || { echo 'Usage: build HOST' >&2; exit 1; }
      bash modules/fleet/ready.sh "$1"
      exec nix build --no-update-lock-file ".#nixosConfigurations.$1.config.system.build.toplevel"
    '';
    disk-plan.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      [[ $# == 1 ]] || { echo 'Usage: disk-plan HOST' >&2; exit 1; }
      bash modules/fleet/ready.sh "$1" disk-plan
      exec nix build --no-update-lock-file --out-link "result-disko-$1" ".#nixosConfigurations.$1.config.system.build.diskoScript"
    '';
    deploy.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      exec nix run --no-update-lock-file .#deploy-rs -- "$@"
    '';
    deploy-fleet.exec = ''
      set -euo pipefail
      cd "$DEVENV_ROOT"
      [[ $# == 0 ]] || { echo 'Usage: deploy-fleet' >&2; exit 1; }
      devenv tasks run repo:check-full --mode before
      nix eval --no-update-lock-file --json .#deploy.nodes --apply builtins.attrNames | jq -e 'length > 0' > /dev/null
      exec deploy . -- --no-update-lock-file
    '';
    tailnet.exec = ''
      exec bash "$DEVENV_ROOT/modules/tailscale/tailscale-tofu.sh" "$@"
    '';
    tailnet-sops.exec = ''
      exec python3 "$DEVENV_ROOT/modules/tailscale/tailscale-sops.py" "$@"
    '';
  };

  enterTest = ''
    devenv tasks run repo:check-full --mode before
  '';

  assertions = [
    {
      # Module/CLI compatibility is exercised by the native task contract/tests,
      # not inferred from upstream's occasionally stale latest-version marker.
      assertion = config.devenv.cli.version == pkgs.devenv.version;
      message = "Use the locked CLI: nix run --no-update-lock-file .#devenv -- shell.";
    }
    {
      assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
      message = "This fleet's development environment and provider lock support x86_64-linux only.";
    }
    {
      assertion = !config.secretspec.enable && !config.dotenv.enable;
      message = "Load operator secrets only in the explicit tailnet-sops process, never into Nix or the development shell.";
    }
  ];
}
