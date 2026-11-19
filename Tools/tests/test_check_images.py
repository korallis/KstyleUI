"""Reject the evidence-image paths previously committed in #489, #500 and #491."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from test_pre_commit_config import read_config

REPO = Path(__file__).resolve().parents[2]
CHECK = REPO / "Tools/hooks/check_images.py"


class CheckImagesTest(unittest.TestCase):
    def check(self, root):
        return subprocess.run([sys.executable, str(CHECK)], cwd=root,
                              capture_output=True, text=True)

    def test_current_tree_passes(self):
        result = self.check(REPO)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_tracked_image_fixtures(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            for path, code in (
                ("Tools/render/evidence/bags-steady/x.png", 1),
                ("docs/media/review/meters-both/x.jpg", 1),
                ("Tools/render/evidence/map-icons-1920x1080.png", 1),
                ("docs/media/readme/x.jpg", 0),
                ("Media/Textures/x.blp", 0),
                ("Tools/media/materials/x.png", 0),
                *((f"evidence/x{i}{suffix}", 1) for i, suffix in enumerate
                  ((".png", ".jpg", ".jpeg", ".webp", ".gif", ".tga", ".blp", ".PNG"))),
            ):
                with self.subTest(path=path):
                    image = root / path
                    image.parent.mkdir(parents=True, exist_ok=True)
                    image.write_bytes(b"")
                    self.assertEqual(self.check(root).returncode, 0, "Untracked images are ignored")
                    subprocess.run(["git", "add", "--", path], cwd=root, check=True)
                    result = self.check(root)
                    self.assertEqual(result.returncode, code, result.stdout + result.stderr)
                    if code:
                        self.assertIn(f"Evidence renders are not committed: remove {path} "
                                      "and put it in the PR body; published pictures live in ",
                                      result.stdout)
                    subprocess.run(["git", "rm", "--cached", "-q", "--", path], cwd=root, check=True)

    def test_hook_checks_all_tracked_paths(self):
        hook = read_config()[1]["published-images"]
        self.assertEqual(hook["entry"], "python Tools/hooks/check_images.py")
        self.assertEqual(hook["language"], "python")
        self.assertEqual(hook["pass_filenames"], "false")
        self.assertEqual(hook["always_run"], "true")


if __name__ == "__main__":
    unittest.main()
