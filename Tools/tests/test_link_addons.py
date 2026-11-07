"""Tests for Tools/dev/link-addons.sh against temporary folders."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "dev" / "link-addons.sh"


class LinkAddonsTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.live = self.tmp / "live"
        self.addons = self.tmp / "AddOns"
        self.addons.mkdir()
        for folder in ("Core", "KstyleUI_Foo", "Tools/spikes/KstyleUI_Spike"):
            (self.live / folder).mkdir(parents=True)
        (self.live / "KstyleUI.toc").write_text("## Title: KstyleUI\n")

    def tearDown(self):
        self._tmp.cleanup()

    def run_script(self, *args, **changes):
        env = dict(os.environ, KSTYLEUI_LIVE=str(self.live), WOW_ADDONS=str(self.addons))
        for key, value in changes.items():
            if value is None:
                env.pop(key, None)
            else:
                env[key] = value
        return subprocess.run([os.environ.get("TEST_BASH", "bash"), str(SCRIPT), *args], env=env, capture_output=True, text=True)

    def make_checkout(self, path):
        (path / "KstyleUI_Bar").mkdir(parents=True)
        (path / "KstyleUI.toc").write_text("## Title: KstyleUI\n")
        return path

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

    def test_defaults_to_kstyleui_in_home(self):
        checkout = self.make_checkout(self.tmp / "home" / "KstyleUI")
        result = self.run_script(HOME=str(self.tmp / "home"), KSTYLEUI_LIVE=None)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.link("KstyleUI"), str(checkout))
        self.assertEqual(self.link("KstyleUI_Bar"), str(checkout / "KstyleUI_Bar"))

    def test_kstyleui_live_overrides_the_default(self):
        self.make_checkout(self.tmp / "home" / "KstyleUI")
        result = self.run_script(HOME=str(self.tmp / "home"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.link("KstyleUI"), str(self.live))
        self.assertFalse((self.addons / "KstyleUI_Bar").exists())

    def test_missing_checkout_fails_and_creates_nothing(self):
        shutil.rmtree(self.live)
        for args in ((), ("--dry-run",)):
            with self.subTest(args=args):
                result = self.run_script(*args)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(str(self.live), result.stderr)
                self.assertFalse(self.live.exists())
                self.assertEqual(list(self.addons.iterdir()), [])

    def test_folder_without_the_toc_fails(self):
        (self.live / "KstyleUI.toc").unlink()
        for args in ((), ("--dry-run",)):
            with self.subTest(args=args):
                result = self.run_script(*args)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(str(self.live), result.stderr)
                self.assertEqual(list(self.addons.iterdir()), [])

if __name__ == "__main__":
    unittest.main()
