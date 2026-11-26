from __future__ import annotations

import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
WSTACK = HERE.parent
spec = importlib.util.spec_from_file_location("list_images", WSTACK / "list-images.py")
li = importlib.util.module_from_spec(spec)
sys.modules["list_images"] = li
spec.loader.exec_module(li)

RENDERED = """
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      initContainers:
        - name: init
          image: 'registry.example.org/ocm-wstack/init:1.0.0'
      containers:
        - image: "registry.example.org/ocm-wstack/issuance-service:2.1.0"
          name: main
        - name: sidecar
          image: registry.example.org/tsa/signer:2.3.8
---
apiVersion: batch/v1
kind: Job
spec:
  template:
    spec:
      containers:
        - {name: job, image: registry.example.org/tsa/signer:2.3.8}
---
# an empty document
---
apiVersion: v1
kind: ConfigMap
data:
  image: ""
"""


class ListImages(unittest.TestCase):
    def test_all_forms_found_once(self):
        self.assertEqual(
            li.list_images(RENDERED),
            [
                "registry.example.org/ocm-wstack/init:1.0.0",
                "registry.example.org/ocm-wstack/issuance-service:2.1.0",
                "registry.example.org/tsa/signer:2.3.8",
            ],
        )

    def test_no_images(self):
        self.assertEqual(li.list_images("apiVersion: v1\nkind: Service\n"), [])


class MirrorScriptArguments(unittest.TestCase):
    """Argument handling only: these runs stop before any clone or network call."""

    def run_script(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["bash", str(WSTACK / "mirror-wstack-images.sh"), *args],
            capture_output=True,
            text=True,
            timeout=30,
        )

    def test_help(self):
        r = self.run_script("--help")
        self.assertEqual(r.returncode, 0)
        self.assertIn("Usage:", r.stdout)

    def test_unknown_option(self):
        r = self.run_script("--bogus")
        self.assertEqual(r.returncode, 2)
        self.assertIn("Unknown option", r.stderr)

    def test_apply_needs_target(self):
        r = self.run_script("--apply")
        self.assertEqual(r.returncode, 2)
        self.assertIn("--apply needs --target", r.stderr)


if __name__ == "__main__":
    unittest.main()
