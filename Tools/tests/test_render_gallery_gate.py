"""The requested portable renders gallery must pass without hiding real suppressions."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class RenderGalleryGateTest(unittest.TestCase):
    def test_portable_gallery_and_real_suppression(self):
        env = {key: value for key, value in os.environ.items()
               if not key.startswith(('GIT_AUTHOR_', 'GIT_COMMITTER_'))}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def run(*args):
                return subprocess.run(args, cwd=root, env=env, capture_output=True, text=True)
            self.assertEqual(run('git', 'init', '-q').returncode, 0)
            self.assertEqual(run('git', 'commit', '--allow-empty', '-qm', 'chore: baseline').returncode, 0)
            for name in ('docs/renders/index.html', 'docs/renders/media/hunter.png'):
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / name).read_bytes())
            self.assertEqual(run('git', 'add', 'docs').returncode, 0)
            self.assertEqual(run('git', 'commit', '-qm', 'docs: add gallery').returncode, 0)
            result = run('python3', str(ROOT / 'Tools/hooks/check_images.py'))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = run('bash', str(ROOT / 'scripts/check-suppressions.sh'), 'HEAD^')
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            page = root / 'docs/renders/index.html'
            marker = 'work' + 'around'
            page.write_text(page.read_text().replace('</body>', f'<!-- {marker} --></body>'))
            self.assertEqual(run('git', 'add', str(page)).returncode, 0)
            self.assertEqual(run('git', 'commit', '-qm', 'docs: add marker').returncode, 0)
            result = run('bash', str(ROOT / 'scripts/check-suppressions.sh'), 'HEAD~2')
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn(marker, result.stdout)


if __name__ == '__main__':
    unittest.main()
