"""Post a release's changelog to Discord without blocking publication."""

import argparse
import json
import os
import re
import time
import urllib.request
from pathlib import Path


def split_messages(text):
    messages, current = [], ""
    for line in text.splitlines():
        if current and len(current) + len(line) + 1 > 2000:
            messages.append(current)
            current = ""
        while len(line) > 2000:
            messages.append(line[:2000])
            line = line[2000:]
        current += ("\n" if current else "") + line
    if current:
        messages.append(current)
    return messages


def release_messages(changelog, tag):
    heading = re.search(r"^## %s \(\d{4}-\d{2}-\d{2}\)$" % re.escape(tag), changelog, re.M)
    if not heading:
        raise ValueError("Missing release section")
    section = re.split(r"^## ", changelog[heading.end():], maxsplit=1, flags=re.M)[0].strip()
    section = re.sub(r"^### (.+)$", r"**\1**", section, flags=re.M)
    links = ("Downloads:\n"
             "CurseForge: https://www.curseforge.com/wow/addons/kstyleui\n"
             "Wago: https://addons.wago.io/addons/kstyleui\n"
             f"GitHub: https://github.com/korallis/KstyleUI/releases/tag/{tag}")
    return split_messages(f"KstyleUI {tag} is out\n\n{section}") + split_messages(links)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    webhook = os.environ.get("DISCORD_RELEASE_WEBHOOK", "").strip()
    if not webhook and not args.dry_run:
        print("::notice::Discord release post skipped: webhook is not set.")
        return
    try:
        changelog = Path(__file__).resolve().parents[2] / "CHANGELOG.md"
        for index, message in enumerate(release_messages(changelog.read_text(encoding="utf-8"), args.tag)):
            if args.dry_run:
                print(f"--- Message {index + 1} ({len(message)} characters) ---\n{message}")
                continue
            if index:
                time.sleep(1)
            payload = json.dumps({"content": message, "flags": 4, "allowed_mentions": {"parse": []}}).encode()
            request = urllib.request.Request(webhook, data=payload,
                                             headers={"Content-Type": "application/json", "User-Agent": "KstyleUI-release"})
            with urllib.request.urlopen(request, timeout=30):
                pass
    except (OSError, ValueError):
        print("::warning::Discord release post failed; release uploads are unaffected.")


if __name__ == "__main__":
    main()
