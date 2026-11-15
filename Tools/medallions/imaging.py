"""Image steps of the Medallions pipeline, in Pillow only: the judge's measurements, the clean and bake steps and the
contact sheets. KSTY-87 section 4 and 5.3 set the rules: ship size-specific files baked in linear light, and draw every
1 px line procedurally at the shipped size instead of trusting a generated hairline.
"""

import math
from array import array

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageMath, ImageStat

WORK = 256  # the judge measures every image at this size
DARK = (11, 12, 14)  # the procedural edge colour, Tokens' near-black
EDGE_STRENGTH = 0.85
CREST_FILL = 900 / 1024  # a crest's longest side, as a share of its canvas (KSTY-88's recipe)
ALPHA_FLOOR = 14  # generated haze below this alpha is cut to nothing
SHARPEN = dict(radius=0.6, percent=45, threshold=1)  # KSTY-87's light unsharp after a large reduction

# Judge thresholds, calibrated on the approved KSTY-87 and KSTY-88 art (docs/medallions.md lists the numbers).
CENTRE_TOLERANCE = 0.08
DRIFT_TOLERANCE = 0.25  # bust luminance and saturation over the disc, against the portrait anchor
BADGE_SAT_TOLERANCE = 0.50  # a badge against its own bust: the flat cut is bolder in colour by design
BACKGROUND_MAX = 60  # mean sRGB luma of the ring above the head
BADGE_CONTRAST_MIN = 40.0  # luma standard deviation inside the circle at 24 px
BADGE_SEPARATION_MIN = 15.0  # face centre minus outer ring, mean luma at 24 px
CREST_CORNER_MAX = 6  # mean alpha of the canvas corners: the background must be transparent
CREST_FILL_RANGE = (0.6, 1.0)  # the crest's longest side as a share of the canvas, before the bake refits it
SILHOUETTE_IOU_MIN = 0.93  # an edit's silhouette against its master's
FRAME_MAE_MAX = 0.12  # an edit's frame band against its master, mean absolute difference of 0..1 RGB
FRAME_LUMA_DRIFT = 0.20
CHANGE_THRESHOLD = 60  # largest channel difference that marks an interior pixel as part of the new emblem
EMBLEM_CHANGED_MIN = 0.05  # share of the interior the new emblem must change
HUE_TOLERANCE = 40
WHITE_SHARE_MIN = 0.30  # a white emblem: share of its bright pixels with saturation under 0.25

_TO_LINEAR = [((c / 255 + 0.055) / 1.055) ** 2.4 if c / 255 > 0.04045 else c / 255 / 12.92 for c in range(256)]
_STEPS = 4095
_TO_SRGB = [0] * 65536
for _v in range(_STEPS + 1):
    _x = _v / _STEPS
    _TO_SRGB[_v] = min(255, round(255 * (1.055 * _x ** (1 / 2.4) - 0.055 if _x > 0.0031308 else 12.92 * _x)))
_UNIT = [c / 255 for c in range(256)]


def _math(fn, **images):
    return ImageMath.lambda_eval(lambda a: fn(a), **images)


def _to_srgb(channel):
    clipped = _math(lambda a: a["min"](a["max"](a["x"], 0.0), 1.0), x=channel)
    return clipped.point(lambda x: x * _STEPS + 0.5).convert("I").point(_TO_SRGB, "L")


def _unit(channel):
    return channel.point(_UNIT, "F")


def resize_linear(image, size, sharpen=True):
    """Resize in linear light with premultiplied alpha and Lanczos, then a light unsharp after a large reduction."""
    r, g, b, a = image.convert("RGBA").split()
    alpha = _unit(a)
    planes = [_math(lambda x: x["c"] * x["a"], c=c.point(_TO_LINEAR, "F"), a=alpha) for c in (r, g, b)]
    planes = [p.resize(size, Image.LANCZOS) for p in planes]
    alpha = alpha.resize(size, Image.LANCZOS)
    safe = _math(lambda x: x["max"](x["a"], 0.0001), a=alpha)
    rgb = [_to_srgb(_math(lambda x: x["c"] / x["a"], c=p, a=safe)) for p in planes]
    out = Image.merge("RGBA", (*rgb, _to_srgb_alpha(alpha)))
    if sharpen and size[0] < image.size[0] / 1.5:
        sharp = Image.merge("RGB", out.split()[:3]).filter(ImageFilter.UnsharpMask(**SHARPEN))
        out = Image.merge("RGBA", (*sharp.split(), out.split()[3]))
    return out


def _to_srgb_alpha(alpha):
    return _math(lambda a: a["min"](a["max"](a["x"], 0.0), 1.0) * 255 + 0.5, x=alpha).convert("L")


def disc(size, radius=None, scale=8):
    """Coverage of a centred disc at the shipped size, drawn at scale times and box-filtered down."""
    radius = size / 2 if radius is None else radius
    big = Image.new("L", (size * scale, size * scale), 0)
    c = size * scale / 2
    ImageDraw.Draw(big).ellipse((c - radius * scale, c - radius * scale, c + radius * scale, c + radius * scale), 255)
    return big.resize((size, size), Image.BOX)


def clean_alpha(image, floor=ALPHA_FLOOR):
    """Cut generated haze: alpha below the floor becomes fully transparent."""
    r, g, b, a = image.convert("RGBA").split()
    return Image.merge("RGBA", (r, g, b, a.point(lambda v: 0 if v < floor else v)))


def alpha_box(image, threshold=24):
    return image.getchannel("A").point(lambda v: 255 if v > threshold else 0).getbbox()


def normalise_crest(image, size=WORK):
    """Clean the alpha, trim to the crest and fit its longest side to CREST_FILL of a square canvas."""
    image = clean_alpha(image)
    box = alpha_box(image)
    if box is None:
        return Image.new("RGBA", (size, size))
    crop = image.crop(box)
    s = size * CREST_FILL / max(crop.size)
    fitted = resize_linear(crop, (max(1, round(crop.width * s)), max(1, round(crop.height * s))), sharpen=False)
    canvas = Image.new("RGBA", (size, size))
    canvas.alpha_composite(fitted, ((size - fitted.width) // 2, (size - fitted.height) // 2))
    return canvas


# Bake ------------------------------------------------------------------------------------------------------------

def bake_portrait(image, size):
    """A bust or badge at its shipped size: linear-light reduction, a disc alpha and a 1 px dark rim on its edge."""
    out = resize_linear(image.convert("RGB").convert("RGBA"), (size, size))
    outer, inner = disc(size), disc(size, size / 2 - 1)
    rim = _math(lambda a: (a["o"] - a["i"]) / 255.0 * EDGE_STRENGTH, o=outer.convert("F"), i=inner.convert("F"))
    keep = _math(lambda a: 1.0 - a["r"], r=rim)
    channels = [_math(lambda a, d=d: a["c"] * a["k"] + d * a["r"], c=c.convert("F"), k=keep, r=rim).convert("L")
                for c, d in zip(out.split()[:3], DARK)]
    return Image.merge("RGBA", (*channels, outer))


def bake_crest(image, size):
    """A crest at its shipped size with a procedural 1 px dark outline just outside its silhouette."""
    crest = normalise_crest(image, size)
    ring = crest.getchannel("A").filter(ImageFilter.MaxFilter(3))
    ring = ring.point(lambda v: round(v * EDGE_STRENGTH))
    edge = Image.merge("RGBA", (*(Image.new("L", crest.size, d) for d in DARK), ring))
    edge.alpha_composite(crest)
    return edge


def _hsv_planes(image):
    h, s, v = image.convert("RGB").convert("HSV").split()
    return h, _unit(s), _unit(v)


def _ramp(plane, lo, hi):
    return _math(lambda a: a["min"](a["max"]((a["p"] - lo) / (hi - lo), 0.0), 1.0), p=plane)


def crest_masks(crest):
    """The glow mask (bright, saturated enamel and gems) and the metal mask (bright, unsaturated) for bloom and sheen,
    each white with the mask in alpha so the client can tint and blend it."""
    _, s, v = _hsv_planes(crest)
    a = _unit(crest.getchannel("A"))
    glow = _math(lambda x: x["g"] * x["b"] * x["a"], g=_ramp(s, 0.35, 0.75), b=_ramp(v, 0.5, 0.9), a=a)
    metal = _math(lambda x: (1.0 - x["g"]) * x["b"] * x["a"], g=_ramp(s, 0.10, 0.45), b=_ramp(v, 0.25, 0.75), a=a)
    white = Image.new("L", crest.size, 255)
    return tuple(Image.merge("RGBA", (white, white, white, _to_srgb_alpha(m))) for m in (glow, metal))


# Judge -------------------------------------------------------------------------------------------------------------

def _fsum(plane):
    return math.fsum(array("f", plane.convert("F").tobytes()))


def _mean(plane, mask=None):
    """Mean of a plane (L or F) over a mask (L, 255 inside)."""
    if mask is None:
        return _fsum(plane) / (plane.width * plane.height)
    weight = _fsum(mask) / 255
    if not weight:
        return 0.0
    return _fsum(_math(lambda a: a["p"] * a["m"] / 255.0, p=plane.convert("F"), m=mask.convert("F"))) / weight


def _ring_mask(size, r0, r1, top_only=False):
    mask = Image.new("L", (size, size), 0)
    c = size / 2
    draw = ImageDraw.Draw(mask)
    draw.ellipse((c - r1, c - r1, c + r1, c + r1), 255)
    draw.ellipse((c - r0, c - r0, c + r0, c + r0), 0)
    if top_only:
        draw.rectangle((0, c, size, size), 0)
    return mask


def _centroid(mask):
    w, h = mask.size
    data = mask.load()
    total = sx = sy = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if data[x, y]:
                total += 1
                sx += x
                sy += y
    return (sx / total / w, sy / total / h) if total else (None, None)


def portrait_metrics(image):
    """Luminance, saturation, background and subject centre of a bust or badge, measured at WORK px."""
    im = image.convert("RGB").resize((WORK, WORK), Image.LANCZOS)
    luma = im.convert("L")
    _, s, _ = _hsv_planes(im)
    inside = disc(WORK, WORK * 0.48).point(lambda v: 255 if v > 127 else 0)
    background = _mean(luma, _ring_mask(WORK, WORK * 0.40, WORK * 0.50, top_only=True))
    subject = luma.point(lambda v, b=background: 255 if v > b + 40 else 0)
    subject = Image.composite(subject, Image.new("L", subject.size, 0), inside)
    cx, cy = _centroid(subject)
    return {"luma": round(_mean(luma, inside), 2), "sat": round(_mean(s, inside), 4),
            "background": round(background, 2), "cx": None if cx is None else round(cx, 4),
            "cy": None if cy is None else round(cy, 4)}


def badge_readability(image, size=24):
    """Contrast of a badge reduced to size px: the spread of luma in the circle and the face's lift from its ring."""
    small = resize_linear(image.convert("RGB").convert("RGBA"), (size, size)).convert("L")
    inside = disc(size, size * 0.48).point(lambda v: 255 if v > 127 else 0)
    centre = disc(size, size * 0.28).point(lambda v: 255 if v > 127 else 0)
    ring = _ring_mask(size, size * 0.36, size * 0.5)
    return {"contrast": round(ImageStat.Stat(small, inside).stddev[0], 2),
            "separation": round(_mean(small, centre) - _mean(small, ring), 2)}


def _drift(value, reference):
    return abs(value - reference) / max(abs(reference), 1e-6)


def judge_portrait(image, reference, badge=False):
    """Reasons to reject a bust or badge; an empty list accepts it. reference is portrait_metrics of the portrait
    anchor for a bust, and of the badge's own bust for a badge."""
    m = portrait_metrics(image)
    reasons = []
    if m["cx"] is None:
        reasons.append("no subject stands out from the background")
    elif abs(m["cx"] - 0.5) > CENTRE_TOLERANCE or abs(m["cy"] - reference["cy"]) > CENTRE_TOLERANCE:
        reasons.append(f"off-centre (subject at {m['cx']:.2f}, {m['cy']:.2f})")
    if m["background"] > BACKGROUND_MAX:
        reasons.append(f"bright background ({m['background']:.0f})")
    for name, tolerance in (("luma", DRIFT_TOLERANCE), ("sat", BADGE_SAT_TOLERANCE if badge else DRIFT_TOLERANCE)):
        drift = _drift(m[name], reference[name])
        if drift > tolerance:
            reasons.append(f"{'luminance' if name == 'luma' else 'saturation'} drift {drift:.0%}")
    if badge:
        r = badge_readability(image)
        m.update(r)
        if r["contrast"] < BADGE_CONTRAST_MIN or r["separation"] < BADGE_SEPARATION_MIN:
            reasons.append(f"not readable at 24 px (contrast {r['contrast']:.0f}, separation {r['separation']:.0f})")
    return m, reasons


def _interior(alpha, share=0.22):
    solid = alpha.point(lambda v: 255 if v > 128 else 0)
    box = solid.getbbox()
    k = max(3, int(max(box[2] - box[0], box[3] - box[1]) * share) | 1) if box else 3
    return solid, solid.filter(ImageFilter.MinFilter(k))


def _emblem_colour(crest, region):
    """The new emblem's glow: the circular mean hue of its bright, saturated pixels, weighted by saturation and value,
    and the share of its bright pixels that are white."""
    h, s, v = _hsv_planes(crest)
    hd, sd, vd, rd = h.load(), s.load(), v.load(), region.load()
    x = y = weight = 0.0
    bright = white = 0
    for py in range(region.height):
        for px in range(region.width):
            if not rd[px, py] or vd[px, py] <= 0.6:
                continue
            bright += 1
            if sd[px, py] < 0.25:
                white += 1
            elif sd[px, py] > 0.35:
                w = sd[px, py] * vd[px, py]
                angle = hd[px, py] / 255 * 2 * math.pi
                x += w * math.cos(angle)
                y += w * math.sin(angle)
                weight += w
    hue = round(math.degrees(math.atan2(y, x)) % 360, 1) if weight >= 20 else None
    return hue, round(white / bright, 4) if bright else 0.0


def crest_metrics(raw, master=None):
    """Measurements of a raw crest: transparency, placement and, for an edit of a race master, the drift of its frame
    and the colour of the emblem it changed."""
    raw = raw.convert("RGBA")
    a = raw.getchannel("A")
    w, h = raw.size
    k = max(4, w // 32)
    corners = [a.crop(b) for b in ((0, 0, k, k), (w - k, 0, w, k), (0, h - k, k, h), (w - k, h - k, w, h))]
    box = alpha_box(clean_alpha(raw)) or (0, 0, 0, 0)
    m = {"corner_alpha": round(sum(_mean(c) for c in corners) / 4, 2),
         "cx": round((box[0] + box[2]) / 2 / w, 4), "cy": round((box[1] + box[3]) / 2 / h, 4),
         "fill": round(max(box[2] - box[0], box[3] - box[1]) / max(w, h), 4)}
    crest = normalise_crest(raw)
    solid, interior = _interior(crest.getchannel("A"))
    luma = crest.convert("RGB").convert("L")
    m["luma"] = round(_mean(luma, solid), 2)
    if master is None:
        return m
    ref = normalise_crest(master.convert("RGBA"))
    ref_solid, ref_interior = _interior(ref.getchannel("A"))
    both = ImageChops.multiply(solid, ref_solid)
    union = ImageChops.lighter(solid, ref_solid)
    m["iou"] = round(_count(both) / max(1, _count(union)), 4)
    band = ImageChops.subtract(both, ref_interior)
    if band.getbbox():
        delta = [_mean(ImageChops.difference(c1, c2), band) / 255
                 for c1, c2 in zip(crest.convert("RGB").split(), ref.convert("RGB").split())]
        m["frame_mae"] = round(sum(delta) / 3, 4)
        m["frame_luma_drift"] = round(_drift(_mean(luma, band), _mean(ref.convert("RGB").convert("L"), band)), 4)
    else:
        m["frame_mae"], m["frame_luma_drift"] = 1.0, 1.0
    r, g, b = ImageChops.difference(crest.convert("RGB"), ref.convert("RGB")).split()
    changed = ImageChops.lighter(ImageChops.lighter(r, g), b)
    changed = ImageChops.multiply(changed.point(lambda v: 255 if v > CHANGE_THRESHOLD else 0), interior)
    m["emblem_changed"] = round(_count(changed) / max(1, _count(interior)), 4)
    m["hue"], m["white"] = _emblem_colour(crest, changed)
    return m


def _count(mask):
    return mask.histogram()[255]


def _hue_distance(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


def judge_crest(raw, glow_hues, master=None):
    """Reasons to reject a raw crest; an empty list accepts it. An edit is judged against its race master: the frame
    must stay and the changed emblem must glow in the class colour (glow_hues is the class's tables.GLOW_HUES entry).
    A race master has no master; its colour is checked by eye on the contact sheet."""
    m = crest_metrics(raw, master)
    reasons = []
    if m["corner_alpha"] > CREST_CORNER_MAX:
        reasons.append(f"background not transparent (corner alpha {m['corner_alpha']:.0f})")
    if abs(m["cx"] - 0.5) > CENTRE_TOLERANCE or abs(m["cy"] - 0.5) > CENTRE_TOLERANCE:
        reasons.append(f"off-centre (crest at {m['cx']:.2f}, {m['cy']:.2f})")
    if not CREST_FILL_RANGE[0] <= m["fill"] <= CREST_FILL_RANGE[1]:
        reasons.append(f"crest fills {m['fill']:.0%} of the canvas")
    if master is None:
        return m, reasons
    if m["iou"] < SILHOUETTE_IOU_MIN:
        reasons.append(f"silhouette drift from the master (IoU {m['iou']:.2f})")
    if m["frame_mae"] > FRAME_MAE_MAX:
        reasons.append(f"frame drift from the master ({m['frame_mae']:.3f})")
    if m["frame_luma_drift"] > FRAME_LUMA_DRIFT:
        reasons.append(f"frame luminance drift {m['frame_luma_drift']:.0%}")
    if m["emblem_changed"] < EMBLEM_CHANGED_MIN:
        reasons.append(f"emblem unchanged ({m['emblem_changed']:.0%} of the field)")
    elif glow_hues is None:
        if m["white"] < WHITE_SHARE_MIN:
            reasons.append(f"emblem not white ({m['white']:.0%} of its bright pixels)")
    elif m["hue"] is None:
        reasons.append("no class glow in the emblem")
    elif min(_hue_distance(m["hue"], want) for want in glow_hues) > HUE_TOLERANCE:
        reasons.append(f"emblem glow hue {m['hue']:.0f}, wanted {' or '.join(str(x) for x in glow_hues)}")
    return m, reasons


# Contact sheets ----------------------------------------------------------------------------------------------------

SHEET_BACK = (21, 23, 27)


def contact_sheet(rows, sizes, title=""):
    """rows: (label, tiles) pairs, one tile per size in sizes, shown side by side on the slate."""
    pad, label_h = 12, 16
    width = pad + sum(s + pad for s in sizes) + 220
    height = pad + label_h + sum(max(sizes) + pad for _ in rows)
    sheet = Image.new("RGB", (width, height), SHEET_BACK)
    draw = ImageDraw.Draw(sheet)
    draw.text((pad, pad - 4), title, fill=(200, 205, 212))
    y = pad + label_h
    for label, tiles in rows:
        x = pad
        for s, tile in zip(sizes, tiles):
            tile = tile.convert("RGBA")
            sheet.paste(tile, (x, y + (max(sizes) - s) // 2), tile)
            x += s + pad
        draw.text((x, y + max(sizes) // 2 - 6), label, fill=(200, 205, 212))
        y += max(sizes) + pad
    return sheet
