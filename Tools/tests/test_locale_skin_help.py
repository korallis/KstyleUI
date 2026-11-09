"""Every skin's help, in every locale, stays under the 100-byte limit Skins.Add enforces on the translated string.

KstyleUI_Skins/Registry.lua rejects a definition whose help is 100 bytes or longer, and def.help is the translated
L["..."] string, so one long translation stops that skin from registering for every player of that locale.
"""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIMIT = 100
HELP = re.compile(r'\n\thelp = L\["((?:[^"\\]|\\.)*)"\]')


def skin_helps():
    keys = {}
    for path in sorted((ROOT / "KstyleUI_Skins").rglob("*.lua")):
        text = path.read_bytes().decode("ascii").replace("\r\n", "\n")
        for match in HELP.finditer(text):
            keys[match.group(1)] = path.relative_to(ROOT).as_posix()
    return keys


class SkinHelpLength(unittest.TestCase):
    def test_finds_the_skins(self):
        keys = skin_helps()
        self.assertGreaterEqual(len(keys), 20)
        self.assertIn("KstyleUI_Skins/Encounter/Warnings.lua", keys.values())

    def test_every_translation_fits(self):
        keys = skin_helps()
        for path in sorted((ROOT / "Tools" / "locale").glob("*.json")):
            table = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(table, dict):
                continue
            for key, where in keys.items():
                self.assertLess(len(key.encode("utf-8")), LIMIT, "%s: the English help is too long" % where)
                text = table.get(key)
                if text is not None:
                    self.assertLess(len(text.encode("utf-8")), LIMIT, "%s %s: %d bytes: %s" % (path.stem, where, len(text.encode("utf-8")), text))


if __name__ == "__main__":
    unittest.main()
