"""The portable gallery must pass the gate without hiding real suppressions."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class RenderGalleryGateTest(unittest.TestCase):
    def test_gallery_image_payloads_and_suppression_scope(self):
        env = {key: value for key, value in os.environ.items()
               if not key.startswith(('GIT_AUTHOR_', 'GIT_COMMITTER_'))}
        payload = (ROOT / 'Tools/tests/fixtures/gallery-icon-base64.txt').read_text().strip()
        marker = 'no' + 'sec'
        self.assertIn(marker, payload.lower())
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def run(*args):
                if args[0] == 'git':
                    args = ('git', '-c', 'user.name=t', '-c', 'user.email=t@example.com',
                            '-c', 'commit.gpgsign=false', *args[1:])
                return subprocess.run(args, cwd=root, env=env, capture_output=True, text=True)

            def commit(message):
                self.assertEqual(run('git', 'add', '-A').returncode, 0)
                result = run('git', 'commit', '-qm', message)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(run('git', 'log', '-1', '--format=%an <%ae>').stdout.strip(),
                                 't <t@example.com>')

            def scan():
                return run('bash', str(ROOT / 'scripts/check-suppressions.sh'), 'HEAD^')

            self.assertEqual(run('git', 'init', '-q').returncode, 0)
            self.assertEqual(run('git', 'commit', '--allow-empty', '-qm', 'chore: baseline').returncode, 0)
            for name in ('docs/renders/index.html', 'docs/renders/phone.html'):
                page = root / name
                page.parent.mkdir(parents=True, exist_ok=True)
                page.write_text(f'<article><img src="data:image/png;base64,{payload}"></article>\n')
            image = root / 'docs/renders/media/hunter.png'
            image.parent.mkdir(parents=True, exist_ok=True)
            image.write_bytes((ROOT / 'docs/renders/media/hunter.png').read_bytes())
            commit('docs: add gallery')
            result = run('python3', str(ROOT / 'Tools/hooks/check_images.py'))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = scan()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

            phone = root / 'docs/renders/phone.html'
            phone.write_text(phone.read_text().replace('</article>', f'<!-- {marker} --></article>'))
            commit('docs: add marker')
            result = scan()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(marker, result.stdout.lower())

            phone.write_text(phone.read_text().replace(f'<!-- {marker} -->', ''))
            commit('docs: remove marker')
            other = root / 'docs/other.html'
            other.write_text(f'<img src="data:image/png;base64,{payload}">\n')
            commit('docs: add other image')
            result = scan()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(marker, result.stdout.lower())

            other.unlink()
            commit('docs: remove other image')
            phone.write_text(phone.read_text().replace('</article>', f'<p>src="data:image/png;base64,{payload}"</p></article>'))
            commit('docs: add image text')
            result = scan()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(marker, result.stdout.lower())


if __name__ == '__main__':
    unittest.main()
