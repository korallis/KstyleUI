"""Keep tracked images in published-picture and source-asset folders."""

import subprocess
from pathlib import PurePosixPath

ALLOWED = (
    "Media/",
    "docs/media/readme/", "docs/media/marketing/", "docs/media/plates/", "docs/media/faq/",
    "docs/store/", "docs/design/mockups/",
    "KstyleUI_DataBars/Media/", "KstyleUI_Minimap/Media/",
    "Tools/icons/setB/Icons/", "Tools/medallions/anchors/", "Tools/media/materials/",
    "Tools/regression/fixtures/paths/", "Tools/spikes/KstyleUI_Spike/Media/",
)
IMAGES = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".tga", ".blp"}


def main():
    paths = subprocess.check_output(["git", "ls-files", "-z"]).decode("utf-8").split("\0")
    failed = False
    for path in paths:
        if PurePosixPath(path).suffix.lower() in IMAGES and not path.startswith(ALLOWED):
            print(f"Evidence renders are not committed: remove {path} and put it in the PR body; "
                  "published pictures live in docs/media/readme, marketing, plates or faq.")
            failed = True
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
