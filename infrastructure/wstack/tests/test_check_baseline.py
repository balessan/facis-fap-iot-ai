from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("check_baseline", HERE.parent / "check-baseline.py")
cb = importlib.util.module_from_spec(spec)
sys.modules["check_baseline"] = cb
spec.loader.exec_module(cb)

REG = "registry.example.org"
D = "sha256:" + "a" * 64
D2 = "sha256:" + "b" * 64
HEADER = (
    "# deployment @ 55e28aa (ref main), generated 2026-10-30T20:43:12Z\n"
    "kind\tsource\tdigest\tused_by\n"
)
CVS = "ocm-wstack/credential-verification-service"


def lock_text(
    overrides: dict[str, str] | None = None, extra: str = "", drop: str | None = None
) -> str:
    tags = {p: "1.0.0" for p in cb.REQUIRED_IMAGES}
    tags["ocm-wstack/credential-verification-service"] = "1.3.7-alpha"
    tags.update(overrides or {})
    rows = [f"image\t{REG}/{p}:{t}\t{D}\tOCM W-Stack/{p}" for p, t in tags.items() if p != drop]
    return HEADER + "\n".join(rows) + "\n" + extra


def all_running(host: str = REG, prefix: str = "", digest: str = D, skip: str | None = None):
    """One running container per required image, as kubectl reports them."""
    base = f"{host}/{prefix}" if prefix else host
    return [
        (f"{p.rsplit('/', 1)[1]}-0/main", f"{base}/{p}:1.0.0", f"{base}/{p}@{digest}")
        for p in cb.REQUIRED_IMAGES
        if p != skip
    ]


def run_offline(text: str, expect: str | None = None) -> cb.Report:
    r = cb.Report()
    lock = cb.parse_lock(text, r)
    if lock is not None:
        cb.check_offline(lock, r, expect)
    return r


class Offline(unittest.TestCase):
    def test_valid_lock_passes(self):
        r = run_offline(lock_text())
        self.assertEqual(r.failures, [])

    def test_repository_lock_passes(self):
        r = cb.Report()
        lock = cb.parse_lock(cb.DEFAULT_LOCK.read_text(), r)
        self.assertIsNotNone(lock)
        cb.check_offline(lock, r)
        self.assertEqual(r.failures, [], r.failures)

    def test_bad_header(self):
        r = run_offline("kind\tsource\tdigest\tused_by\n")
        self.assertIn("header", r.failures[0])

    def test_unresolved_digest(self):
        r = run_offline(lock_text(extra=f"image\t{REG}/x/y:1.0.0\tUNRESOLVED\tz\n"))
        self.assertTrue(any("UNRESOLVED" in f for f in r.failures))

    def test_malformed_digest(self):
        r = run_offline(lock_text(extra=f"chart\t{REG}/x/y:1.0.0-helm\tsha256:1234\tz\n"))
        self.assertTrue(any("not sha256" in f for f in r.failures))

    def test_duplicate(self):
        line = f"chart\t{REG}/x/y:1.0.0-helm\t{D}\tz\n"
        r = run_offline(lock_text(extra=line + line))
        self.assertTrue(any("duplicate" in f for f in r.failures))

    def test_missing_required_image(self):
        r = run_offline(lock_text(drop="tsa/signer"))
        self.assertTrue(any("tsa/signer" in f for f in r.failures))

    def test_verifier_below_minimum(self):
        r = run_offline(lock_text({"ocm-wstack/credential-verification-service": "1.2.2-alpha"}))
        self.assertTrue(any("older than the minimum" in f for f in r.failures))

    def test_pre_release_is_below_its_release(self):
        r = run_offline(lock_text({CVS: "1.3.0-alpha"}))
        self.assertTrue(any("older than the minimum" in f for f in r.failures))

    def test_later_pre_release_meets_minimum(self):
        r = run_offline(lock_text({CVS: "1.3.7-alpha"}))
        self.assertEqual(r.failures, [])

    def test_every_row_of_an_image_is_checked(self):
        old = f"image\t{REG}/{CVS}:1.2.2-alpha\t{D2}\tz\n"
        r = run_offline(lock_text(extra=old))  # the old row comes after the good one
        self.assertTrue(any("1.2.2-alpha is older" in f for f in r.failures))

    def test_version_tuple(self):
        self.assertLess(cb.version_tuple("1.3.0-alpha"), cb.version_tuple("1.3.0"))
        self.assertGreater(cb.version_tuple("v1.3.7-alpha"), cb.version_tuple("1.3.0"))
        self.assertIsNone(cb.version_tuple("dev"))

    def test_wrong_deployment_commit(self):
        r = run_offline(lock_text(), expect="c1ba65c")
        self.assertTrue(any("expected c1ba65c" in f for f in r.failures))

    def test_matching_deployment_commit(self):
        r = run_offline(lock_text(), expect="55e28aa")
        self.assertEqual(r.failures, [])

    def test_non_version_tag_warns(self):
        r = run_offline(lock_text(extra=f"image\t{REG}/x/bootstrap:dev\t{D}\tz\n"))
        self.assertEqual(r.failures, [])
        self.assertTrue(any("not a version" in w for w in r.warnings))


class Registry(unittest.TestCase):
    def setUp(self):
        self.lock = cb.parse_lock(lock_text(), cb.Report())

    def test_no_drift(self):
        r = cb.Report()
        cb.check_registry(self.lock, r, strict=True, resolver=lambda s: D)
        self.assertEqual((r.failures, r.warnings), ([], []))

    def test_drift_warns_by_default(self):
        r = cb.Report()
        cb.check_registry(self.lock, r, strict=False, resolver=lambda s: D2)
        self.assertEqual(r.failures, [])
        self.assertTrue(r.warnings)

    def test_drift_fails_when_strict(self):
        r = cb.Report()
        cb.check_registry(self.lock, r, strict=True, resolver=lambda s: D2)
        self.assertTrue(r.failures)

    def test_unresolvable_fails(self):
        r = cb.Report()
        cb.check_registry(self.lock, r, strict=False, resolver=lambda s: None)
        self.assertTrue(r.failures)

    def test_timeout_counts_as_unresolved(self):
        def slow(*args, **kwargs):
            raise cb.subprocess.TimeoutExpired(cmd="skopeo", timeout=120)

        real = cb.subprocess.run
        cb.subprocess.run = slow
        try:
            self.assertIsNone(cb.resolve_digest(f"{REG}/x/y:1.0.0"))
        finally:
            cb.subprocess.run = real


class Cluster(unittest.TestCase):
    def setUp(self):
        self.lock = cb.parse_lock(lock_text(), cb.Report())
        self.cvs = f"{REG}/ocm-wstack/credential-verification-service:1.3.7-alpha"

    def test_pinned_digests_running(self):
        r = cb.Report()
        cb.check_cluster(self.lock, r, all_running())
        self.assertEqual((r.failures, r.warnings), ([], []))

    def test_mirror_without_prefix_matches(self):
        r = cb.Report()
        cb.check_cluster(self.lock, r, all_running(host="mirror.example.net"))
        self.assertEqual((r.failures, r.warnings), ([], []))

    def test_mirror_with_prefix_matches(self):
        r = cb.Report()
        running = all_running(host="harbor.example.org", prefix="facis-mirror")
        cb.check_cluster(self.lock, r, running)
        self.assertEqual((r.failures, r.warnings), ([], []))

    def test_mirror_with_prefix_wrong_digest_fails(self):
        r = cb.Report()
        running = all_running(host="harbor.example.org", prefix="facis-mirror", skip=CVS)
        running.append(
            (
                "cvs-0/cvs",
                f"harbor.example.org/facis-mirror/{CVS}:1.3.7-alpha",
                f"harbor.example.org/facis-mirror/{CVS}@{D2}",
            )
        )
        cb.check_cluster(self.lock, r, running)
        self.assertTrue(any("runs sha256:bbbb" in f for f in r.failures), r.failures)

    def test_other_digest_running(self):
        r = cb.Report()
        running = all_running(skip=CVS) + [("cvs-0/cvs", self.cvs, f"{REG}/{CVS}@{D2}")]
        cb.check_cluster(self.lock, r, running)
        self.assertTrue(r.failures)

    def test_missing_required_service_fails(self):
        r = cb.Report()
        cb.check_cluster(self.lock, r, all_running(skip=CVS))
        self.assertTrue(any("no running container" in f and CVS in f for f in r.failures))

    def test_only_unrelated_pods_fail(self):
        r = cb.Report()
        running = [("nats-0/nats", "docker.io/library/nats:2.10", f"docker.io/library/nats@{D}")]
        cb.check_cluster(self.lock, r, running)
        self.assertEqual(len(r.failures), len(cb.REQUIRED_IMAGES))

    def test_unknown_image_warns(self):
        r = cb.Report()
        running = all_running() + [
            ("nats-0/nats", "docker.io/library/nats:2.10", f"docker.io/library/nats@{D}")
        ]
        cb.check_cluster(self.lock, r, running)
        self.assertEqual(r.failures, [])
        self.assertTrue(r.warnings)

    def test_empty_namespace_fails(self):
        r = cb.Report()
        cb.check_cluster(self.lock, r, [])
        self.assertTrue(r.failures)


class Arguments(unittest.TestCase):
    def test_strict_needs_registry(self):
        with self.assertRaises(SystemExit) as cm:
            cb.main(["--strict"])
        self.assertEqual(cm.exception.code, 2)

    def test_context_needs_cluster(self):
        with self.assertRaises(SystemExit) as cm:
            cb.main(["--context", "some-context"])
        self.assertEqual(cm.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
