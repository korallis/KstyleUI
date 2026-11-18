"""Crop real Forever screenshots without painting, inpainting or replacing pixels.

    python Tools/media/plates.py [--source ~/.cache/kstyleui-backdrops]

Crop boxes use source pixels, left/top inclusive and right/bottom exclusive.
"""

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/media/plates"
SPECS = {
    "forest-1080.jpg": ("game_09.png", (0, 300, 1520, 1155), (1920, 1080)),
    "forest-ultrawide.jpg": ("game_09.png", (0, 300, 2048, 876), (5120, 1440)),
    "forest-mac.jpg": ("game_09.png", (0, 300, 1296, 1138), (3456, 2234)),
    "town-1080.jpg": ("game_03.png", (0, 400, 1440, 1210), (1920, 1080)),
    "town-ultrawide.jpg": ("game_03.png", (0, 768, 1600, 1218), (5120, 1440)),
    "town-mac.jpg": ("game_03.png", (0, 400, 1248, 1207), (3456, 2234)),
    "minimap.png": ("game_09.png", (4910, 70, 5038, 198), (256, 256)),
}


def main(argv=None):
    from PIL import Image
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", type=Path, default=Path.home() / ".cache/kstyleui-backdrops")
    args = parser.parse_args(argv)
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for name, (source, box, size) in SPECS.items():
        path = args.source / source
        with Image.open(path) as image:
            assert image.size == (5120, 1440), path
            crop = image.crop(box).resize(size, Image.Resampling.LANCZOS)
            crop.save(OUT / name, **({"quality": 90, "optimize": True} if name.endswith(".jpg") else {}))
        manifest[name] = {"source": source, "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                          "crop": box, "size": size,
                          "sha256": hashlib.sha256((OUT / name).read_bytes()).hexdigest()}
        print(name, source, box, size)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
