"""Tests for Tools/build/gen_widget_methods.py."""

import contextlib
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "Tools" / "build"))

import gen_widget_methods  # noqa: E402

DOCS = Path("Interface") / "AddOns" / "Blizzard_APIDocumentationGenerated"


def doc_table(name, kind, functions):
    """Return the text of one generated documentation file, in Blizzard's layout."""
    entries = "".join(
        f'\t\t{{\n\t\t\tName = "{fn}",\n\t\t\tType = "Function",\n\n'
        f'\t\t\tArguments =\n\t\t\t{{\n\t\t\t\t{{ Name = "value", Type = "number", Nilable = false }},\n\t\t\t}},\n'
        "\t\t},\n"
        for fn in functions
    )
    return (
        f"local {name} =\n{{\n\tName = \"{name}\",\n\tType = \"{kind}\",\n\tEnvironment = \"All\",\n\n"
        f"\tFunctions =\n\t{{\n{entries}\t}},\n\n\tEvents =\n\t{{\n\t}},\n}};\n\n"
        f"APIDocumentation:AddDocumentationTable({name});\n"
    )


class GenWidgetMethodsTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.source = Path(self._tmp.name) / "wow-ui-source"
        self.docs = self.source / DOCS
        self.docs.mkdir(parents=True)
        self.out = Path(self._tmp.name) / "widget_methods.lua"

    def tearDown(self):
        self._tmp.cleanup()

    def write_doc(self, file, name, kind, functions):
        (self.docs / file).write_text(doc_table(name, kind, functions), encoding="utf-8")

    def commit_source(self, subject):
        git = ["git", "-C", str(self.source), "-c", "user.name=t", "-c", "user.email=t@example.com"]
        subprocess.run(git + ["init", "-q"], check=True)
        subprocess.run(git + ["add", "-A"], check=True)
        subprocess.run(git + ["commit", "-q", "-m", subject], check=True)
        return subprocess.run(
            git + ["log", "-1", "--format=%h"], check=True, capture_output=True, text=True
        ).stdout.strip()

    def generate(self):
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr), contextlib.redirect_stdout(io.StringIO()):
            code = gen_widget_methods.main(["--source", str(self.source), "--out", str(self.out)])
        return code, stderr.getvalue()

    def test_collects_only_script_object_methods(self):
        self.write_doc("SimpleRegionAPIDocumentation.lua", "SimpleRegionAPI", "ScriptObject", ["SetAlpha", "GetAlpha"])
        self.write_doc("FrameScriptDocumentation.lua", "FrameScript", "System", ["issecretvalue", "CreateFromMixins"])
        self.assertEqual(gen_widget_methods.collect(self.source), ["GetAlpha", "SetAlpha"])

    def test_merges_types_sorted_without_duplicates(self):
        self.write_doc("SimpleFrameAPIDocumentation.lua", "SimpleFrameAPI", "ScriptObject", ["SetScript", "Show"])
        self.write_doc("SimpleTextureAPIDocumentation.lua", "SimpleTextureAPI", "ScriptObject", ["SetTexture", "Show"])
        self.assertEqual(gen_widget_methods.collect(self.source), ["SetScript", "SetTexture", "Show"])

    def test_writes_a_lua_list_with_a_header_naming_the_source_commit(self):
        self.write_doc("SimpleRegionAPIDocumentation.lua", "SimpleRegionAPI", "ScriptObject", ["SetAlpha", "GetAlpha"])
        commit = self.commit_source("1.60.1 (70840)")
        code, _ = self.generate()
        self.assertEqual(code, 0)
        lines = self.out.read_text(encoding="utf-8").splitlines()
        self.assertTrue(lines[0].startswith("-- widget_methods.lua: "), lines[0])
        self.assertIn(f"{commit} 1.60.1 (70840)", lines[0])
        self.assertEqual(lines[1:], ["return {", '\t"GetAlpha",', '\t"SetAlpha",', "}"])

    def test_fails_without_writing_when_the_docs_are_missing(self):
        self.docs.rmdir()
        code, err = self.generate()
        self.assertEqual(code, 1)
        self.assertIn("Blizzard_APIDocumentationGenerated", err)
        self.assertFalse(self.out.exists())

    def test_fails_without_writing_when_no_widget_methods_are_found(self):
        self.write_doc("FrameScriptDocumentation.lua", "FrameScript", "System", ["issecretvalue"])
        self.commit_source("empty")
        code, err = self.generate()
        self.assertEqual(code, 1)
        self.assertIn("no widget methods", err)
        self.assertFalse(self.out.exists())


if __name__ == "__main__":
    unittest.main()
