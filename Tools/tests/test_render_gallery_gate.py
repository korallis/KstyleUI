"""The portable gallery must pass the gate without hiding real suppressions."""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class RenderGalleryGateTest(unittest.TestCase):
    def test_gallery_image_payloads_and_suppression_scope(self):
        env = {key: value for key, value in os.environ.items()
               if not key.startswith(('GIT_AUTHOR_', 'GIT_COMMITTER_'))}
        env['KSTYLEUI_PYTHON'] = sys.executable
        env['PYTHONIOENCODING'] = 'ascii'
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

            scan_env = dict(env)
            if os.name != 'nt':
                tools = root / 'tools'
                tools.mkdir()
                for name in ('git', 'bash', 'awk', 'dirname', 'sort', 'head', 'tr', 'mktemp', 'rm', 'grep'):
                    (tools / name).symlink_to(shutil.which(name))
                scan_env['PATH'] = str(tools)

            def scan():
                return subprocess.run([shutil.which('bash'), str(ROOT / 'scripts/check-suppressions.sh'), 'HEAD^'],
                                      cwd=root, env=scan_env, capture_output=True, text=True)

            self.assertEqual(run('git', 'init', '-q').returncode, 0)
            self.assertEqual(run('git', 'commit', '--allow-empty', '-qm', 'chore: baseline').returncode, 0)
            for name in ('docs/renders/index.html', 'docs/renders/phone.html'):
                page = root / name
                page.parent.mkdir(parents=True, exist_ok=True)
                page.write_text(f'<article><p>KstyleUI · Artwork</p><img src="data:image/png;base64,{payload}"></article>', encoding='utf-8')
            image = root / 'docs/renders/media/hunter.png'
            image.parent.mkdir(parents=True, exist_ok=True)
            image.write_bytes((ROOT / 'docs/renders/media/hunter.png').read_bytes())
            commit('docs: add gallery')
            result = run(sys.executable, str(ROOT / 'Tools/hooks/check_images.py'))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = scan()
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

            for name in ('docs/renders/index.html', 'docs/renders/phone.html'):
                page = root / name
                original = page.read_text(encoding='utf-8')
                page.write_text(original.replace('</article>', '\n<!--\n-->\n</article>'), encoding='utf-8')
                commit('docs: add comment')
                page.write_text(page.read_text(encoding='utf-8').replace('<!--\n-->', f'<!--\n<img src="data:image/png;base64,{payload}">\n-->'), encoding='utf-8')
                commit('docs: add image comment')
                result = scan()
                page.write_text(original, encoding='utf-8')
                commit('docs: remove image comment')
                with self.subTest(gallery=name):
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(marker, result.stdout.lower())

            phone = root / 'docs/renders/phone.html'
            phone.write_text(phone.read_text(encoding='utf-8').replace('</article>', f'<!-- {marker} --></article>'), encoding='utf-8')
            commit('docs: add marker')
            result = scan()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(marker, result.stdout.lower())

            phone.write_text(phone.read_text(encoding='utf-8').replace(f'<!-- {marker} -->', ''), encoding='utf-8')
            commit('docs: remove marker')
            other = root / 'docs/other.html'
            other.write_text(f'<img src="data:image/png;base64,{payload}">\n')
            commit('docs: add other image')
            result = scan()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(marker, result.stdout.lower())

            other.unlink()
            commit('docs: remove other image')
            phone.write_text(phone.read_text(encoding='utf-8').replace('</article>', f'<p>src="data:image/png;base64,{payload}"</p></article>'), encoding='utf-8')
            commit('docs: add image text')
            result = scan()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(marker, result.stdout.lower())


if __name__ == '__main__':
    unittest.main()
