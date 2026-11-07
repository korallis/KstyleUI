"""Tests for Tools/dev/link-addons.sh against temporary folders."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "dev" / "link-addons.sh"


def git(cwd, *args):
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", *args], cwd=cwd, check=True, capture_output=True)


class LinkAddonsTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.live = self.tmp / "live"
        self.addons = self.tmp / "AddOns"
        self.addons.mkdir()
        for folder in ("Core", "KstyleUI_Foo", "Tools/spikes/KstyleUI_Spike"):
            (self.live / folder).mkdir(parents=True)

    def tearDown(self):
        self._tmp.cleanup()

    def run_script(self, *args, script=SCRIPT):
        env = dict(os.environ, KSTYLEUI_LIVE=str(self.live), WOW_ADDONS=str(self.addons))
        return subprocess.run([os.environ.get("TEST_BASH", "bash"), str(script), *args], env=env, capture_output=True, text=True)

    def link(self, name):
        path = self.addons / name
        return os.readlink(path) if path.is_symlink() else None

    def test_links_core_and_modules(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.link("KstyleUI"), str(self.live))
        self.assertEqual(self.link("KstyleUI_Foo"), str(self.live / "KstyleUI_Foo"))
        self.assertFalse((self.addons / "KstyleUI_Spike").exists())

    def test_second_run_changes_nothing(self):
        self.run_script()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("link ", result.stdout)
        self.assertEqual(self.link("KstyleUI"), str(self.live))

    def test_spike_flag_links_spike(self):
        self.run_script("--spike")
        self.assertEqual(self.link("KstyleUI_Spike"), str(self.live / "Tools/spikes/KstyleUI_Spike"))

    def test_replaces_a_wrong_symlink(self):
        (self.addons / "KstyleUI").symlink_to(self.tmp)
        self.run_script()
        self.assertEqual(self.link("KstyleUI"), str(self.live))

    def test_relative_live_path_links_an_absolute_target(self):
        env = dict(os.environ, KSTYLEUI_LIVE="live", WOW_ADDONS=str(self.addons))
        bash = os.environ.get("TEST_BASH", "bash")
        result = subprocess.run([bash, str(SCRIPT)], env=env, cwd=self.tmp, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(Path(self.link("KstyleUI")).resolve(), self.live.resolve())
        self.assertTrue(os.path.isabs(self.link("KstyleUI")))

    def test_refuses_a_real_folder(self):
        real = self.addons / "KstyleUI"
        real.mkdir()
        (real / "keep.txt").write_text("keep")
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertIn(str(real), result.stdout + result.stderr)
        self.assertTrue((real / "keep.txt").exists())
        self.assertFalse((self.addons / "KstyleUI_Foo").exists())

    def test_dry_run_changes_nothing(self):
        result = self.run_script("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"link {self.addons}/KstyleUI -> {self.live}", result.stdout)
        self.assertIn(f"link {self.addons}/KstyleUI_Foo -> {self.live}/KstyleUI_Foo", result.stdout)
        self.assertEqual(list(self.addons.iterdir()), [])

    def test_creates_the_live_worktree_on_staging(self):
        src = self.tmp / "src"
        src.mkdir()
        git(src, "init", "-q", "-b", "main")
        (src / "README.md").write_text("x\n")
        git(src, "add", ".")
        git(src, "commit", "-q", "-m", "main")
        git(src, "checkout", "-q", "-b", "staging")
        (src / "KstyleUI_Bar").mkdir()
        (src / "KstyleUI_Bar" / "KstyleUI_Bar.toc").write_text("x\n")
        git(src, "add", ".")
        git(src, "commit", "-q", "-m", "staging")
        git(src, "checkout", "-q", "main")
        repo = self.tmp / "repo"
        git(self.tmp, "clone", "-q", str(src), str(repo))
        (repo / "Tools" / "dev").mkdir(parents=True)
        shutil.copy(SCRIPT, repo / "Tools" / "dev" / "link-addons.sh")
        shutil.rmtree(self.live)

        result = self.run_script(script=repo / "Tools" / "dev" / "link-addons.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        branch = subprocess.run(["git", "-C", str(self.live), "branch", "--show-current"], capture_output=True, text=True)
        self.assertEqual(branch.stdout.strip(), "staging")
        self.assertEqual(self.link("KstyleUI_Bar"), str(self.live / "KstyleUI_Bar"))


if __name__ == "__main__":
    unittest.main()
