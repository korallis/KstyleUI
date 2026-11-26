"""Contributor contract: both instruction entry points deliver the same ASCII/CRLF guide."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class AgentGuidesTest(unittest.TestCase):
    def test_both_readers_receive_the_same_ascii_crlf_guide(self):
        guide = (ROOT / "AGENTS.md").read_bytes()
        self.assertTrue(guide == (ROOT / "CLAUDE.md").read_bytes(),
                        "Copy AGENTS.md to CLAUDE.md after editing the guide.")
        self.assertTrue(guide.strip(), "Both guides must contain instructions.")
        self.assertTrue(guide.isascii(), "Save the guide as ASCII.")
        self.assertTrue(guide.endswith(b"\r\n"), "End the guide with CRLF.")
        lines = guide.split(b"\r\n")
        self.assertFalse(any(b"\r" in line or b"\n" in line for line in lines),
                         "Use CRLF for every line in the guide.")
