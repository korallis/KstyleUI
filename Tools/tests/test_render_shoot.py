"""Exercise shoot.sh's complete launcher with a fake browser and scene writer."""
import os
from pathlib import Path
import shutil
import tempfile
import unittest

from Tools.tests.subprocess_budget import run as budgeted_run

ROOT = Path(__file__).resolve().parents[2]
BASH = os.environ.get("TEST_BASH", "bash")


class ShootURLs(unittest.TestCase):
    def test_browser_urls_and_assets_use_native_absolute_paths(self):
        with tempfile.TemporaryDirectory(prefix="render urls #") as folder:
            root = Path(folder)
            render = root / "Tools/render"
            (render / "scenes").mkdir(parents=True)
            shutil.copyfile(ROOT / "Tools/render/shoot.sh", render / "shoot.sh")
            (render / "scenes/smoke.lua").write_text("Common.Run\n", newline="\n")
            lua = root / "lua"
            lua.write_text('''#!/usr/bin/env bash
if [[ "$1" == *guard.lua ]]; then exit 0; fi
echo '{"screen":{"width":10,"height":10},"items":[]}' > "$2"
''', newline="\n")
            chrome = root / "chrome"
            chrome.write_text('''#!/usr/bin/env bash
printf '%s\\n' "$@" >> "$CHROME_ARGS"
for arg in "$@"; do
    case "$arg" in --screenshot=*) printf 'PNG' > "${arg#--screenshot=}";; esac
done
echo '<title>rendered</title>'
''', newline="\n")
            lua.chmod(0o755)
            chrome.chmod(0o755)
            backdrop = root / "bright ground #1.png"
            backdrop.touch()
            forms = [str(backdrop)]
            if os.name == "nt":
                forms.append(backdrop.as_posix())
                forms.append("/" + backdrop.drive[0].lower() + backdrop.as_posix()[2:])
            for form in forms:
                with self.subTest(backdrop=form):
                    args_file = root / "chrome.args"
                    args_file.write_text("")
                    env = dict(os.environ, LUA=lua.as_posix(), CHROME=chrome.as_posix(),
                               CHROME_ARGS=args_file.as_posix())
                    result = budgeted_run([BASH, str(render / "shoot.sh"), "smoke", "--no-standins",
                                             "--backdrop", form, "--strict"],
                                            env=env, text=True, capture_output=True, cpu_budget=30)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    page = (render / "out/smoke.html").read_text()
                    self.assertIn('base:"' + root.as_uri() + '/"', page)
                    self.assertIn('backdrop:"' + backdrop.as_uri() + '"', page)
                    self.assertIn('src="' + (render / "render.js").as_uri() + '"', page)
                    calls = args_file.read_text().splitlines()
                    self.assertEqual(calls.count((render / "out/smoke.html").as_uri()), 2,
                                     "both Chrome passes need the native file:/// page URL")


if __name__ == "__main__":
    unittest.main()
