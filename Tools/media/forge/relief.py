"""relief.py: turn a layered 2D emblem into a height map Blender can forge.

An emblem is drawn in a unit box (x right, y down, as Tools/media/sigils.py draws). Each layer is a mask raised to a
height with a rounded shoulder, so stacked layers read as cast relief: a head, a brow over it, a beak over that.
Writes <name>_h.png (16-bit height), <name>_m.png (silhouette) and <name>_c.png (cavity, for patina) into a folder.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

N = 1024


def spline(points, closed=True, steps=14):
    """A Catmull-Rom curve through the points."""
    pts = [np.array(p, float) for p in points]
    n = len(pts)
    out = []
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0 = pts[(i - 1) % n] if closed or i > 0 else pts[i]
        p1, p2 = pts[i], pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if closed or i + 2 < n else pts[i + 1]
        for s in range(steps):
            t = s / steps
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    if not closed:
        out.append(pts[-1])
    return [(float(x), float(y)) for x, y in out]


def mask_poly(points):
    im = Image.new("L", (N, N), 0)
    ImageDraw.Draw(im).polygon([(x * N, y * N) for x, y in points], fill=255)
    return np.asarray(im) > 127


def blob(points, steps=14):
    """A smooth closed shape through the points."""
    return mask_poly(spline(points, True, steps))


def poly(points):
    """A hard-cornered shape."""
    return mask_poly(points)


def ellipse(cx, cy, rx, ry=None, rot=0.0):
    ry = rx if ry is None else ry
    a = math.radians(rot)
    pts = []
    for k in range(96):
        t = 2 * math.pi * k / 96
        x, y = rx * math.cos(t), ry * math.sin(t)
        pts.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
    return mask_poly(pts)


def stroke(points, w0, w1=None, smooth=True, closed=False, steps=14, cap=True):
    """A stroke along the points, tapering from w0 to w1."""
    w1 = w0 if w1 is None else w1
    path = spline(points, closed, steps) if smooth else list(points)
    n = len(path)
    left, right = [], []
    for i, (x, y) in enumerate(path):
        x0, y0 = path[max(0, i - 1)]
        x1, y1 = path[min(n - 1, i + 1)]
        dx, dy = x1 - x0, y1 - y0
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / ln, dx / ln
        w = (w0 + (w1 - w0) * i / max(1, n - 1)) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    im = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(im)
    for i in range(n - 1):
        d.polygon([(px * N, py * N) for px, py in (left[i], left[i + 1], right[i + 1], right[i])], fill=255)
    if cap:
        for (x, y), w in ((path[0], w0), (path[-1], w1)):
            r = w * N / 2
            d.ellipse([x * N - r, y * N - r, x * N + r, y * N + r], fill=255)
    return np.asarray(im) > 127


def from_image(image, threshold=96):
    """A mask from a generator's own drawing (any size, white on black)."""
    im = image.convert("L").resize((N, N), Image.LANCZOS)
    m = np.asarray(im) > threshold
    # a pen's curved stroke leaves pinholes between its segments: close them, or each becomes a pit
    m = ndi.binary_closing(m, iterations=3)
    holes = ndi.binary_fill_holes(m) & ~m
    lab, n = ndi.label(holes)
    if n:
        sizes = ndi.sum(holes, lab, range(1, n + 1))
        small = np.isin(lab, [k + 1 for k, v in enumerate(sizes) if v < 0.0012 * N * N])
        m |= small
    return m


def transform(mask, dx=0.0, dy=0.0, scale=1.0, rot=0.0, flip=False, about=(0.5, 0.5)):
    im = Image.fromarray((mask * 255).astype(np.uint8))
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    cx, cy = about[0] * N, about[1] * N
    a = math.radians(rot)
    c, s = math.cos(a) / scale, math.sin(a) / scale
    # output (x, y) samples input: rotate and scale about the centre, then shift
    m = (c, s, cx - c * (cx + dx * N) - s * (cy + dy * N), -s, c, cy + s * (cx + dx * N) - c * (cy + dy * N))
    return np.asarray(im.transform((N, N), Image.AFFINE, m, Image.BILINEAR)) > 127


def shoulder(mask, r, prof="round"):
    d = ndi.distance_transform_edt(mask) / N
    t = np.clip(d / max(r, 1e-6), 0, 1)
    if prof == "round":
        return np.sqrt(1 - (1 - t) ** 2)
    if prof == "soft":
        return t * t * (3 - 2 * t)
    return t


class Emblem:
    def __init__(self, name):
        self.name = name
        self.H = np.zeros((N, N), np.float32)
        self.M = np.zeros((N, N), bool)
        self.dark = None
        self.edge = None

    def add(self, mask, h=1.0, r=0.05, base=None, prof="round"):
        """Raise a layer. base is the height at its edge (default: 35% of h, so the wall shows)."""
        base = 0.35 * h if base is None else base
        sh = shoulder(mask, r, prof).astype(np.float32)
        # round off the crease the distance field leaves along a shape's spine
        sig = max(1.0, 0.22 * r * N)
        w = ndi.gaussian_filter(mask.astype(np.float32), sig)
        sh = np.where(mask, ndi.gaussian_filter(sh * mask, sig) / np.maximum(w, 1e-4), 0)
        layer = (base + (h - base) * sh).astype(np.float32)
        self.H = np.where(mask, np.maximum(self.H, layer), self.H)
        self.M |= mask
        return self

    def cut(self, mask, depth=0.25, r=0.012):
        """Engrave a line or a hollow."""
        self.H = np.where(mask, self.H - depth * shoulder(mask, r, "soft"), self.H)
        return self

    def pierce(self, mask):
        """Open a hole right through the figure, so the dark ground shows in it: an eye that still reads at HUD size."""
        self.M &= ~mask
        self.H = np.where(mask, 0, self.H).astype(np.float32)
        return self

    def shade(self, mask):
        """Fill a gap beside the figure with low dark metal, so an open mouth reads as a dark wedge instead of showing the ground through it. Call it before fit(), never before turn()."""
        mask = mask & ~self.M
        self.M |= mask
        self.H = np.where(mask, 0.12, self.H).astype(np.float32)
        self.dark = mask
        return self

    def turn(self, degrees):
        """Turn the whole drawing about the box's centre (positive is clockwise on screen); fit() or seat() then brings it back inside."""
        size = 2 * N
        for attr, mode in (("H", "F"), ("M", "L")):
            src = getattr(self, attr)
            big = Image.new(mode, (size, size), 0)
            big.paste(Image.fromarray(src if mode == "F" else (src * 255).astype(np.uint8)), (N // 2, N // 2))
            out = big.rotate(-degrees, Image.BICUBIC).resize((N, N), Image.BICUBIC)
            setattr(self, attr, np.asarray(out, np.float32).copy() if mode == "F" else np.asarray(out) > 127)
        return self

    def fit(self, margin=0.06):
        """Scale the drawing so its bounds fill the box with a margin, centred."""
        ys, xs = np.nonzero(self.M)
        if len(xs) == 0:
            return self
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        size = max(x1 - x0, y1 - y0)
        target = int(N * (1 - 2 * margin))
        k = target / size
        h = Image.fromarray(self.H[y0:y1, x0:x1]).resize((max(1, round((x1 - x0) * k)), max(1, round((y1 - y0) * k))), Image.BICUBIC)
        ox, oy = (N - h.size[0]) // 2, (N - h.size[1]) // 2

        def placed(mask):
            out = Image.new("L", (N, N), 0)
            out.paste(Image.fromarray((mask[y0:y1, x0:x1] * 255).astype(np.uint8)).resize(h.size, Image.BICUBIC), (ox, oy))
            return np.asarray(out) > 127

        H = Image.new("F", (N, N), 0.0)
        H.paste(h, (ox, oy))
        self.H = np.asarray(H, np.float32).copy()
        if self.dark is not None:
            self.dark = placed(self.dark)
        self.M = placed(self.M)
        return self

    def seat(self, reach=0.40, rim=0.045):
        """Seat the fitted figure on a round dark plate inside a raised rim, so it reads over any ground and covers what lies beneath."""
        self.fit()
        yy, xx = np.mgrid[0:N, 0:N]
        far = np.hypot(xx - N / 2, yy - N / 2)
        k = reach * N / max(float(far[self.M].max()), 1.0)
        box = (1 / k, 0, N / 2 * (1 - 1 / k), 0, 1 / k, N / 2 * (1 - 1 / k))
        H = np.asarray(Image.fromarray(self.H).transform((N, N), Image.AFFINE, box, Image.BICUBIC), np.float32)
        M = np.asarray(Image.fromarray((self.M * 255).astype(np.uint8)).transform((N, N), Image.AFFINE, box, Image.BICUBIC)) > 127
        disc = far <= 0.49 * N
        self.dark = disc & ~M & (far <= (0.49 - rim) * N)
        self.H = np.where(M, 0.3 + H, np.where(self.dark, 0.12, 0.0)).astype(np.float32)
        self.M = disc
        return self.add(disc & (far > (0.49 - rim) * N), h=0.5, r=rim / 2, base=0.2)

    def save(self, folder):
        os.makedirs(folder, exist_ok=True)
        H = np.clip(self.H, 0, None)
        H = ndi.gaussian_filter(H, 1.2) * self.M
        top = max(float(H.max()), 1e-6)
        Hn = H / top
        cav = np.clip((ndi.gaussian_filter(Hn, 14) - Hn) * 3.2, 0, 1)
        edge = np.clip(1 - ndi.distance_transform_edt(self.M) / (0.012 * N), 0, 1) * 0.55
        cav = np.clip(np.maximum(cav, edge), 0, 1)
        if self.dark is not None:
            cav = np.maximum(cav, ndi.gaussian_filter(self.dark.astype(np.float32), 1.5))
        Image.fromarray((Hn * 65535).astype(np.uint16)).save(os.path.join(folder, self.name + "_h.png"))
        soft = ndi.gaussian_filter(self.M.astype(np.float32), 0.8)
        Image.fromarray((np.clip(soft, 0, 1) * 255).astype(np.uint8)).save(os.path.join(folder, self.name + "_m.png"))
        Image.fromarray((cav * 255).astype(np.uint8)).save(os.path.join(folder, self.name + "_c.png"))
        return self


def forge_lineart(name, image, folder, plate=False):
    """Forge a generator's white line drawing: its strokes become raised ridges, the gaps between them left open, or closed by a plate."""
    e = Emblem(name)
    e.add(from_image(image), h=1.0, r=0.022, base=0.27)
    e.seat() if plate else e.fit()
    e.save(folder)
    return e
