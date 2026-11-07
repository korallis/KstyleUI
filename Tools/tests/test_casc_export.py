"""Tests for Tools/icons/casc_export.py, with fake TACTTool and DBC2CSV executables."""

import contextlib
import io
import json
import os
import stat
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "icons"))

import abilities  # noqa: E402
import casc_export  # noqa: E402

BUILD_INFO = (
    "Branch!STRING:0|Active!DEC:1|Build Key!HEX:16|CDN Key!HEX:16|Version!STRING:0|Product!STRING:0\n"
    "eu|0|aaaa|bbbb|1.15.8.60000|wow_classic_era\n"
    "eu|1|6ca8f0e6eae877c8346388d55601a1bc|6aee492112bf17a47b7aae8e30447df2|1.60.1.70840|wowf\n"
)

# Mimics TACTTool's list mode: extracts every listed path under -o, and leaves a listfile and a
# cache folder in its working directory, as the real tool does.
FAKE_TACTTOOL = """
import json, os, sys
args = sys.argv[1:]
opts = dict(zip(args[::2], args[1::2]))
with open(os.environ["FAKE_LOG"], "a") as log:
    log.write(json.dumps({"tool": "tact", "argv": args, "cwd": os.getcwd()}) + "\\n")
if os.environ.get("FAKE_FAIL") == "tact":
    print("could not load build", file=sys.stderr)
    sys.exit(3)
open("listfile.csv", "w").write("1;x\\n")
os.makedirs("cache", exist_ok=True)
for line in open(opts["-i"]):
    line = line.strip()
    if not line or os.environ.get("FAKE_SKIP", "-") in line:
        continue
    path = os.path.join(opts["-o"], line)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(b"WDC5")
"""

# Mimics `dotnet DBC2CSV.dll <folder>`: writes <Table>.csv beside each <Table>.db2.
FAKE_DOTNET = """
import json, os, sys
with open(os.environ["FAKE_LOG"], "a") as log:
    log.write(json.dumps({"tool": "dotnet", "argv": sys.argv[1:], "cwd": os.getcwd()}) + "\\n")
folder = sys.argv[2]
for name in os.listdir(folder):
    if name.endswith(".db2") and name != os.environ.get("FAKE_SKIP_CSV"):
        open(os.path.join(folder, name[:-4] + ".csv"), "w").write("ID,Name_lang\\n1,x\\n")
"""


def snapshot(folder):
    return sorted((str(p.relative_to(folder)), p.stat().st_mtime_ns) for p in folder.rglob("*"))


class CascExportTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.wow = self.root / "World of Warcraft"
        (self.wow / "Data" / "data").mkdir(parents=True)
        (self.wow / ".build.info").write_text(BUILD_INFO, encoding="utf-8")
        (self.wow / "Data" / "data" / "data.000").write_bytes(b"casc")
        self.out = self.root / "cache" / "1.60.1.70840"
        self.log = self.root / "log.jsonl"
        self.tacttool = self.script("TACTTool", FAKE_TACTTOOL)
        self.dotnet = self.script("dotnet", FAKE_DOTNET)
        self.dbc2csv = self.root / "DBC2CSV.dll"
        self.dbc2csv.write_bytes(b"")
        self._env = dict(os.environ)
        os.environ["FAKE_LOG"] = str(self.log)

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self._env)
        self._tmp.cleanup()

    def script(self, name, body):
        path = self.root / "bin" / name
        path.parent.mkdir(exist_ok=True)
        path.write_text(f"#!{sys.executable}\n" + textwrap.dedent(body), encoding="utf-8")
        path.chmod(path.stat().st_mode | stat.S_IXUSR)
        return path

    def run_main(self, *extra, build="1.60.1.70840"):
        args = ["--build", build, "--wow-dir", str(self.wow), "--out", str(self.out)]
        args += ["--tacttool", str(self.tacttool), "--dotnet", str(self.dotnet), "--dbc2csv", str(self.dbc2csv)]
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = casc_export.main(args + list(extra))
        return code, out.getvalue(), err.getvalue()

    def calls(self):
        return [json.loads(line) for line in self.log.read_text(encoding="utf-8").splitlines()]

    def test_reads_active_product_version(self):
        info = casc_export.read_build_info(self.wow, "wowf")
        self.assertEqual(info["Version"], "1.60.1.70840")
        self.assertEqual(info["Build Key"], "6ca8f0e6eae877c8346388d55601a1bc")
        with self.assertRaisesRegex(ValueError, "no wowt install"):
            casc_export.read_build_info(self.wow, "wowt")

    def test_rejects_empty_build_info(self):
        (self.wow / ".build.info").write_text("", encoding="utf-8")
        code, _, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("is empty", err)

    def test_refuses_other_build(self):
        code, _, err = self.run_main(build="1.60.1.99999")
        self.assertEqual(code, 1)
        self.assertIn("1.60.1.70840", err)
        self.assertFalse(self.out.exists())
        self.assertFalse(self.log.exists())

    def test_exports_every_table_without_touching_the_game_folder(self):
        before = snapshot(self.wow)
        code, out, err = self.run_main()
        self.assertEqual(code, 0, err)
        self.assertEqual(snapshot(self.wow), before)
        self.assertEqual(sorted(p.name for p in self.out.iterdir()), sorted(f"{t}.csv" for t in abilities.TABLES))
        self.assertEqual(abilities.load_csv(self.out / "SpellName.csv"), [{"ID": "1", "Name_lang": "x"}])
        self.assertIn(str(self.out), out)

        tact, dotnet = self.calls()
        self.assertEqual(tact["argv"][:6], ["-p", "wowf", "-d", str(self.wow), "-m", "list"])
        for call in (tact, dotnet):
            self.assertFalse(Path(call["cwd"]).resolve().is_relative_to(self.wow.resolve()))
            self.assertFalse(Path(call["cwd"]).exists(), "the work folder is removed")

    def test_accepts_relative_paths(self):
        previous = os.getcwd()
        os.chdir(self.root)
        try:
            out, err = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                code = casc_export.main(
                    [
                        "--build", "1.60.1.70840",
                        "--wow-dir", "World of Warcraft",
                        "--out", "cache/1.60.1.70840",
                        "--tacttool", "bin/TACTTool",
                        "--dotnet", "bin/dotnet",
                        "--dbc2csv", "DBC2CSV.dll",
                    ]
                )
        finally:
            os.chdir(previous)
        self.assertEqual(code, 0, err.getvalue())
        self.assertEqual(len(list(self.out.glob("*.csv"))), len(abilities.TABLES))

    def test_missing_table_writes_nothing(self):
        os.environ["FAKE_SKIP"] = "spellmisc.db2"
        code, _, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("SpellMisc", err)
        self.assertFalse(self.out.exists())

    def test_unconverted_table_writes_nothing(self):
        os.environ["FAKE_SKIP_CSV"] = "Talent.db2"
        code, _, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("did not convert Talent", err)
        self.assertFalse(self.out.exists())

    def test_reports_tool_failure(self):
        os.environ["FAKE_FAIL"] = "tact"
        code, _, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("exit 3", err)
        self.assertIn("could not load build", err)

    def test_reports_missing_tools(self):
        self.tacttool.unlink()
        code, _, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn("install-casc-tools.sh", err)


if __name__ == "__main__":
    unittest.main()
