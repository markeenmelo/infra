"""Independent exact policy oracle, not an implementation of Tailscale's engine.

JSON is a valid HuJSON subset; intentionally keep the live policy in that subset
so canonical checks can reject duplicate keys and unreviewed policy sections.
Family identifiers are synthetic test inputs only, never live policy subjects.
"""
import copy
import json
from pathlib import Path
import sys


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate policy field: {key}")
        result[key] = value
    return result


def check(policy):
    tags = [f"tag:fleet-{host}" for host in ["thinkpad", "racknerd", "bastion", "dino"]]
    assert set(policy) == {"tagOwners", "acls", "ssh", "autoApprovers", "grants", "tests"}
    assert policy["tagOwners"] == {tag: ["autogroup:admin"] for tag in tags}
    assert policy["acls"] == policy["ssh"] == []
    assert policy["autoApprovers"] == {}
    assert policy["grants"] == [{"src": [tags[0]], "dst": tags[1:], "ip": ["tcp:22", "icmp:*"]}]
    # These are the exact native test intentions, independently enumerated.
    expected = [
        {"src": tags[0], "proto": "tcp", "accept": [f"{t}:22" for t in tags[1:]],
         "deny": [f"{tags[1]}:80", f"{tags[2]}:443", f"{tags[3]}:3389"]},
        {"src": tags[0], "proto": "icmp", "accept": [f"{t}:0" for t in tags[1:]]},
        {"src": tags[0], "proto": "udp", "deny": [f"{t}:22" for t in tags[1:]]},
    ]
    for proto, port in [("tcp", 22), ("icmp", 0)]:
        expected.extend({"src": src, "proto": proto,
                         "deny": [f"{dst}:{port}" for dst in tags if src != dst]}
                        for src in tags[1:])
    assert policy["tests"] == expected


policy = json.loads(Path(sys.argv[1]).read_text(), object_pairs_hook=unique)
check(policy)
mutations = [
    {"src": ["*"], "dst": ["*"], "ip": ["*"]},
    {"src": ["autogroup:member"], "dst": ["autogroup:self"], "ip": ["*"]},
    {"src": ["tag:TEST-ONLY-family"], "dst": ["tag:fleet-bastion"], "ip": ["tcp:22"]},
    {"src": ["tag:fleet-bastion"], "dst": ["tag:fleet-thinkpad"], "ip": ["tcp:22"]},
]
for grant in mutations:
    candidate = copy.deepcopy(policy)
    candidate["grants"].append(grant)
    try:
        check(candidate)
    except AssertionError:
        continue
    raise AssertionError("Unreviewed access survived the policy oracle")
for key, value in [("tagOwners", {"tag:fleet-thinkpad": ["autogroup:member"]}),
                   ("ssh", [{"action": "accept"}]), ("tests", []), ("nodeAttrs", [])]:
    candidate = copy.deepcopy(policy)
    candidate[key] = value
    try:
        check(candidate)
    except AssertionError:
        continue
    raise AssertionError("Unreviewed policy change survived the oracle")
print("Exact default-deny policy and eight widening/removal regressions passed (offline).")
