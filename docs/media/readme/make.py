"""Make the README's JPEGs from the render handoff folder.

Usage: python3 docs/media/readme/make.py <handoff folder>

The handoff folder is the one Tools/render writes its final renders into (on the owner's Mac,
~/.local/share/kstyleui-handoff/final). It holds lumen_questing.png and lumen_combat.png (the HUD
at 2384x1541), frames/kstyle_<scene>.png (one render per frame) and classes/<class>_frames.png.
Every output is a JPEG next to this script; the README links them by name. Needs ImageMagick.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(os.path.expanduser(sys.argv[1])) if len(sys.argv) > 1 else None

# name, source, crop (WxH+X+Y or None), width, quality. A crop of "cover" cuts a centred 16:10
# window from the top of the frame, the shape every tile in the "What it changes" grid shares.
IMAGES = [
    ("hero.jpg", "lumen_questing.png", None, 1600, 82),
    ("merit_skins.jpg", "frames/kstyle_skins_character.png", None, 900, 80),
    ("merit_combat.jpg", "lumen_combat.png", "1040x760+760+560", 900, 80),
    ("merit_raid.jpg", "frames/kstyle_groupframes_raid.png", None, 900, 84),
    ("merit_setup.jpg", "frames/kstyle_setup_layouts.png", None, 900, 80),
    ("merit_plates.jpg", "frames/kstyle_nameplates_pull.png", None, 900, 80),
    ("merit_rail.jpg", "lumen_questing.png", "1000x1060+1384+30", 760, 80),
    ("tile_unitframes.jpg", "frames/kstyle_unitframes_preview.png", "cover", 560, 78),
    ("tile_groupframes.jpg", "frames/kstyle_groupframes_party.png", "cover", 560, 78),
    ("tile_actionbars.jpg", "lumen_combat.png", "866x541+820+1000", 560, 78),
    ("tile_cooldowns.jpg", "frames/kstyle_cooldowns_preview.png", "cover", 560, 78),
    ("tile_auras.jpg", "frames/kstyle_auras_preview.png", "cover", 560, 78),
    ("tile_nameplates.jpg", "frames/kstyle_nameplates_pull.png", "850x531+0+0", 560, 78),
    ("tile_minimap.jpg", "frames/kstyle_minimap_preview.png", "cover", 560, 78),
    ("tile_chat.jpg", "frames/kstyle_chat_preview.png", "cover", 560, 78),
    ("tile_bags.jpg", "frames/kstyle_bags_window.png", "cover", 560, 78),
    ("tile_meters.jpg", "frames/kstyle_meters_damage.png", "cover", 560, 78),
    ("tile_skins.jpg", "frames/kstyle_skins_spellbook.png", "cover", 560, 78),
    ("tile_layout.jpg", "frames/kstyle_layout_plates.png", "cover", 560, 78),
]
CLASSES = ["druid", "hunter", "mage", "paladin", "priest", "rogue", "shaman", "warlock", "warrior"]
for cls in CLASSES:
    IMAGES.append((f"class_{cls}.jpg", f"classes/{cls}_frames.png", "640x420+430+170", 560, 78))


def size(path):
    out = subprocess.run(["magick", "identify", "-format", "%w %h", path], check=True, capture_output=True, text=True).stdout
    width, height = out.split()
    return int(width), int(height)


def cover(path):
    """A centred 16:10 window hung from the top edge, never larger than the frame."""
    width, height = size(path)
    crop_w, crop_h = width, width * 10 // 16
    if crop_h > height:
        crop_h, crop_w = height, height * 16 // 10
    return f"{crop_w}x{crop_h}+{(width - crop_w) // 2}+0"


def main():
    if not SRC or not os.path.isdir(SRC):
        sys.exit(__doc__)
    total = 0
    for name, source, crop, width, quality in IMAGES:
        src = os.path.join(SRC, source)
        if crop == "cover":
            crop = cover(src)
        cmd = ["magick", src]
        if crop:
            cmd += ["-crop", crop, "+repage"]
        out = os.path.join(HERE, name)
        cmd += ["-resize", f"{width}x>", "-strip", "-interlace", "Plane", "-quality", str(quality), out]
        subprocess.run(cmd, check=True)
        total += os.path.getsize(out)
        print(f"{name} {'x'.join(map(str, size(out)))} {os.path.getsize(out) // 1024} KB")
    print(f"total {total / 1048576:.2f} MB")


if __name__ == "__main__":
    main()
