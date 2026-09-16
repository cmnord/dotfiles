"""Run with python3 -B -m unittest discover -s tests -v; no real daemon is used."""

import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
OVERRIDES = (
    "DOCKER_HOST", "DOCKER_CONTEXT", "DOCKER_TLS", "DOCKER_TLS_VERIFY",
    "DOCKER_CERT_PATH", "BUILDX_BUILDER", "COLIMA_PROFILE", "LIMA_HOME",
    "XDG_CONFIG_HOME",
)


class CleanupTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="cleanup-test-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        (self.home / ".colima/default").mkdir(parents=True)
        self.stub = self.home / "stub"
        shutil.copyfile(Path(__file__).parent / "fixtures" / "cleanup_stub.py", self.stub)
        (self.bin / "python3").symlink_to(sys.executable)
        self.stub.chmod(0o755)
        for tool in ("docker", "colima", "df"):
            (self.bin / tool).symlink_to(self.stub)
        # An isolated PATH cannot fall through to a developer's real Docker.
        for tool in ("mkdir", "dirname", "date", "tee", "awk"):
            (self.bin / tool).symlink_to(shutil.which(tool))
        self.env = {"HOME": str(self.home), "PATH": str(self.bin)}

    def run_cleanup(self, *args, **env):
        for fixture in ("calls", "df-count", "Library/Logs/conductor-cleanup.log"):
            (self.home / fixture).unlink(missing_ok=True)
        result = subprocess.run(
            ["/bin/bash", str(ROOT / "bin/conductor-cleanup.sh"), *args],
            env={**self.env, **env}, capture_output=True, text=True, timeout=10,
        )
        self.log = (self.home / "Library/Logs/conductor-cleanup.log").read_text()
        calls = self.home / "calls"
        self.calls = [json.loads(line) for line in calls.read_text().splitlines()] if calls.exists() else []
        self.assertNotIn("UNEXPECTED", self.log)
        self.assertNotIn("Traceback", self.log)
        self.assertIn("=== done, freed", self.log)
        return result

    def mutations(self):
        return [args for _, args, _ in self.calls if "prune" in args or "ssh" in args]

    def test_success_and_environment_isolation(self):
        result = self.run_cleanup(
            **dict.fromkeys(OVERRIDES, "remote-or-custom"),
            DOCKER_CONFIG="/custom/docker", COLIMA_HOME="/custom/colima",
            DOCKER_BUILDKIT="1", BUILDKIT_HOST="tcp://remote:1234",
        )
        self.assertEqual(result.returncode, 0, self.log)
        self.assertEqual(len(self.calls), 6)
        self.assertEqual(len(self.mutations()), 3)
        self.assertIn("image", self.mutations()[0])
        self.assertIn("builder", self.mutations()[1])
        self.assertIn("fstrim", self.mutations()[2])
        for _, _, env in self.calls:
            for key in OVERRIDES:
                self.assertNotIn(key, env)
            self.assertEqual(env["DOCKER_CONFIG"], str(self.home / ".docker"))
            self.assertEqual(env["COLIMA_HOME"], str(self.home / ".colima"))
        self.assertIn("Total reclaimed space: 4.071 GB", self.log)
        self.assertIn("20.5 GiB trimmed", self.log)
        self.assertIn("freed 2MB measured", self.log)
        self.assertIn("not host disk recovery", self.log)

    def test_dry_run_never_prunes_or_trims(self):
        result = self.run_cleanup("--dry-run")
        self.assertEqual(result.returncode, 0, self.log)
        self.assertEqual(self.mutations(), [])
        self.assertEqual(self.log.count("DRY-RUN would"), 3)

    def test_missing_tools(self):
        for tool in ("docker", "colima"):
            with self.subTest(tool=tool):
                (self.bin / tool).unlink()
                result = self.run_cleanup()
                (self.bin / tool).symlink_to(self.stub)
                self.assertEqual(result.returncode, 0, self.log)
                self.assertEqual(self.calls, [])
                self.assertIn("not installed", self.log)

    def test_missing_profile(self):
        (self.home / ".colima/default").rmdir()
        result = self.run_cleanup()
        self.assertEqual(result.returncode, 0, self.log)
        self.assertEqual(self.calls, [])
        self.assertIn("default profile is not installed", self.log)

    def test_stopped_profile(self):
        result = self.run_cleanup(TEST_FAIL="status")
        self.assertEqual(result.returncode, 0, self.log)
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(self.mutations(), [])
        self.assertIn("stopped or unavailable", self.log)

    def test_missing_context(self):
        result = self.run_cleanup(TEST_FAIL="context")
        self.assertEqual(result.returncode, 0, self.log)
        self.assertEqual(self.mutations(), [])
        self.assertIn("context is unavailable", self.log)

    def test_rejects_remote_or_custom_context_socket(self):
        for endpoint in ("ssh://remote", "tcp://remote:2375", "unix:///var/run/docker.sock"):
            with self.subTest(endpoint=endpoint):
                result = self.run_cleanup(TEST_ENDPOINT=endpoint)
                self.assertEqual(result.returncode, 1, self.log)
                self.assertEqual(self.mutations(), [])
                self.assertTrue(all("--host" not in args for _, args, _ in self.calls))
                self.assertIn("ERROR: refusing Colima maintenance", self.log)

    def test_daemon_unavailable(self):
        result = self.run_cleanup(TEST_FAIL="info")
        self.assertEqual(result.returncode, 1, self.log)
        self.assertEqual(self.mutations(), [])
        self.assertIn("Docker daemon is unavailable", self.log)

    def test_cleanup_failures_are_visible(self):
        for action, label in (("image", "image prune"), ("builder", "builder prune"),
                              ("trim", "filesystem trim")):
            with self.subTest(action=action):
                result = self.run_cleanup(TEST_FAIL=action)
                self.assertEqual(result.returncode, 1, self.log)
                self.assertEqual(len(self.mutations()), 3)
                self.assertIn(f"fixture failure: {action}", self.log)
                self.assertIn(f"ERROR: Colima {label} failed", self.log)

    def test_launchd_path_and_schedule(self):
        with (ROOT / "launchd/com.cnord.conductor-cleanup.plist").open("rb") as f:
            plist = plistlib.load(f)
        self.assertEqual(plist["StartCalendarInterval"], {"Hour": 12, "Minute": 0})
        path = plist["EnvironmentVariables"]["PATH"].split(":")
        self.assertIn("/opt/homebrew/bin", path)
        self.assertIn("/usr/local/bin", path)


if __name__ == "__main__":
    unittest.main()
