"""Discord release formatting and message limits, without network access."""

import unittest

from Tools.release.discord_post import release_messages, split_messages


class DiscordPostTests(unittest.TestCase):
    def test_only_the_tag_section_is_posted_with_downloads_last(self):
        text = ("## v2.0.0 (2026-11-19)\nNewer\n"
                "## v1.2.3 (2026-11-18)\n\nSummary.\n\n"
                "### Added\n\n- One\n\n### Changed\n\n- Two\n\n### Fixed\n\n- Three\n\n"
                "## How to install\nInstructions")
        messages = release_messages(text, "v1.2.3")
        self.assertEqual(messages[0], "KstyleUI v1.2.3 is out\n\nSummary.\n\n"
                         "**Added**\n\n- One\n\n**Changed**\n\n- Two\n\n**Fixed**\n\n- Three")
        self.assertEqual(messages[1], "Downloads:\n"
                         "CurseForge: https://www.curseforge.com/wow/addons/kstyleui\n"
                         "Wago: https://addons.wago.io/addons/kstyleui\n"
                         "GitHub: https://github.com/korallis/KstyleUI/releases/tag/v1.2.3")
        with self.assertRaises(ValueError):
            release_messages(text, "v1.2.30")

    def test_split_at_line_breaks_and_keep_every_character(self):
        lines = ["a" * 1000, "b" * 999, "c" * 2000, "d"]
        self.assertEqual(split_messages("\n".join(lines)), ["\n".join(lines[:2]), *lines[2:]])
        self.assertEqual(split_messages("x" * 4001), ["x" * 2000, "x" * 2000, "x"])
        self.assertEqual(split_messages(""), [])


if __name__ == "__main__":
    unittest.main()
