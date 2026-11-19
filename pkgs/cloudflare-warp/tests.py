"""Exercise exclusion reconciliation without a daemon or network access."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(sys.argv.pop(1)).resolve()


class ExclusionTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(dir=os.environ["WARP_TEST_TMPDIR"])
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.state = self.root / "state.json"
        self.state.write_text(json.dumps({"ranges": [], "hosts": [], "calls": []}))
        cli = self.root / "warp-cli"
        cli.write_text(f"#!{sys.executable}\n" + '''import json, os, sys
from pathlib import Path
p = Path(os.environ["WARP_MOCK_STATE"])
s = json.loads(p.read_text())
args = sys.argv[1:]
assert args.pop(0) == "--no-ansi"
assert args.pop(0) == "tunnel"
kind, action, *rest = args
key = {"ip": "ranges", "host": "hosts"}[kind]
s["calls"].append([kind, action, *rest])
p.write_text(json.dumps(s))
if os.environ.get("WARP_MOCK_UNAVAILABLE") == "1":
    sys.exit(1)
if action == "list":
    for entry in s[key]:
        print(entry + " (CLI exclude)")
elif os.environ.get("WARP_MOCK_REJECT") == "1":
    sys.exit(2)
else:
    assert action == {"ip": "add-range", "host": "add"}[kind]
    s[key].append(rest[0])
    p.write_text(json.dumps(s))
''')
        cli.chmod(0o755)
        sleep = self.root / "sleep"
        sleep.write_text("#!/bin/sh\nexit 0\n")
        sleep.chmod(0o755)
        self.env = os.environ | {
            "PATH": str(self.root) + os.pathsep + os.environ["PATH"],
            "WARP_CLI": str(cli),
            "WARP_MOCK_STATE": str(self.state),
            "WARP_EXCLUDE_RAYFISH": "true",
            "WARP_EXCLUDE_HOSTS": "example.com\nother.example.com",
        }

    def run_helper(self):
        return subprocess.run(
            ["bash", "-euo", "pipefail", str(SCRIPT)],
            env=self.env, capture_output=True, text=True, timeout=20,
        )

    def test_adds_once_and_preserves_existing_entries(self):
        self.state.write_text(json.dumps({
            "ranges": ["192.0.2.0/24"], "hosts": ["existing.example.com"], "calls": []
        }))
        for _ in range(2):
            result = self.run_helper()
            self.assertEqual(result.returncode, 0, result.stderr)
        state = json.loads(self.state.read_text())
        self.assertEqual(state["ranges"], ["192.0.2.0/24", "200::/7"])
        self.assertEqual(state["hosts"], [
            "existing.example.com", "example.com", "other.example.com"
        ])

    def test_domain_matching_is_exact(self):
        self.state.write_text(json.dumps({
            "ranges": ["200::/7"], "hosts": ["notexample.com", "exampleXcom"], "calls": []
        }))
        self.env["WARP_EXCLUDE_HOSTS"] = "example.com"
        self.assertEqual(self.run_helper().returncode, 0)
        self.assertIn("example.com", json.loads(self.state.read_text())["hosts"])

    def test_rayfish_can_be_disabled_independently(self):
        self.env["WARP_EXCLUDE_RAYFISH"] = "false"
        self.assertEqual(self.run_helper().returncode, 0)
        state = json.loads(self.state.read_text())
        self.assertEqual(state["ranges"], [])
        self.assertEqual(len(state["hosts"]), 2)

    def test_unavailable_daemon_has_a_bounded_retry(self):
        self.env["WARP_MOCK_UNAVAILABLE"] = "1"
        result = self.run_helper()
        self.assertNotEqual(result.returncode, 0)
        state = json.loads(self.state.read_text())
        self.assertEqual(len(state["calls"]), 15)
        self.assertEqual(state["ranges"], [])
        self.assertEqual(state["hosts"], [])

    def test_policy_rejection_is_reported(self):
        self.env["WARP_MOCK_REJECT"] = "1"
        self.assertNotEqual(self.run_helper().returncode, 0)
        state = json.loads(self.state.read_text())
        self.assertEqual(state["ranges"], [])
        self.assertEqual(state["hosts"], [])


if __name__ == "__main__":
    unittest.main()
