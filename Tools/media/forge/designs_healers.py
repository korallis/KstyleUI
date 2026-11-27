"""The priest's, druid's and shaman's crest marks for the aura kit (Tools/media/forge/auras.py).

Each healer mark is flat line art drawn in the game additive over a status bar or a medal: a cooldown sigil
(Tools/media/sigils.py), a figure that burns down (Tools/media/figures.py), a tracker light
(Tools/media/healer_trackers.py), an element rune or the storm orb. Its aura is traced from that same drawing at its
own place in its box, not re-fitted, so the moving light lies exactly over the flat figure the crest draws black under
it and a draining bar cuts both at the same height.

Colour: a sigil burns in its class's crest colour, as its rail tints it today (Nature's Swiftness, which the druid and
the shaman share, in nature green); a figure in the school colour figures.py draws it in; Inner Fire's flame and
the storm orb in their own art's colours; the leaf in nature green; the imbue rune and the element runes white,
because the crest tints them by element.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path[:0] = [str(HERE.parent)]

import figures
import sigils

PRIEST = ("Brave", "Feedback", "Focus", "Infusion", "Lifeline", "Moon", "Sacrifice", "Veil")
DRUID = ("Bark", "Fang", "Innervate", "Mend", "Roots")
SHAMAN = ("Bolt", "Farseer")
COLOURS = {name: "pipPriestGlow" for name in PRIEST}
COLOURS.update({name: "pipDruidGlow" for name in DRUID})
COLOURS.update({name: "pipStormGlow" for name in SHAMAN})
COLOURS["Swift"] = "schoolNature"


def hexed(rgb):
    return "#" + "".join(f"{int(round(v * 255)):02x}" for v in rgb)


def pen(draw):
    def image():
        p = sigils.Pen()
        draw(p)
        return p.image
    return image


def traced(path, threshold=0.5):
    """A shipped additive texture's own body: its alpha past the soft glow, as a white-on-black drawing."""
    def image():
        alpha = np.asarray(Image.open(ROOT / path).convert("RGBA"), np.float32)[..., 3] / 255
        return Image.fromarray(((alpha >= threshold) * 255).astype(np.uint8)).resize((sigils.N, sigils.N), Image.BICUBIC)
    return image


# "Folder/Name" (its sheet, Media/Textures/Auras/Folder/Name.png): (folder, Core/Tokens.lua colour or "#rrggbb", a
# drawing: white on black, any size); the folder in the key keeps the figure Moon apart from the sigil Moon
MARKS = {}
for name, colour in COLOURS.items():
    MARKS["Sigils/" + name] = ("sigils", colour, pen(sigils.GLYPHS[name]))
for name, (draw, colour, _) in figures.FIGURES.items():
    MARKS["Figures/" + name] = ("figures", hexed(colour), pen(draw))
MARKS.update({
    "Trackers/Flame": ("trackers", "#ffbd45", traced("Media/Textures/Medallions/Trackers/Flame.png")),
    "Trackers/Leaf": ("trackers", "schoolNature", traced("Media/Textures/Medallions/Trackers/Leaf.png")),
    "Trackers/Rune": ("trackers", "white", traced("Media/Textures/Medallions/Trackers/Rune.png")),
    "Storm/StormOrb": ("storm", "#7fc4ff", traced("Media/Textures/Medallions/Storm/StormOrb.png", 0.35)),
})
for element in ("Earth", "Fire", "Water", "Air"):
    MARKS["Totems/Rune" + element] = ("totems", "white", traced(f"Media/Textures/Totems/Rune{element}.png"))
