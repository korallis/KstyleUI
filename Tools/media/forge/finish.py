"""finish.py: make a forged render into the texture the game draws: a dark outline baked in, then the size.

Sizes are reduced in linear light on premultiplied colour, as the project's other art tools reduce theirs.
"""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi


def to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def load(path):
    return np.asarray(Image.open(path).convert("RGBA"), np.float32) / 255


def outline(img, width=0.016, color=(0.045, 0.035, 0.03), strength=0.92):
    """Bake a dark outline round the silhouette (width as a share of the picture), so a mark holds its shape over bright ground."""
    a = img[..., 3]
    n = a.shape[0]
    grown = np.clip(ndi.gaussian_filter(ndi.grey_dilation(a, size=int(max(3, width * n * 2)) | 1), 1.0), 0, 1) * strength
    out = np.zeros_like(img)
    oa = grown + a * (1 - grown)
    for k in range(3):
        out[..., k] = (img[..., k] * a + color[k] * grown * (1 - a)) / np.maximum(oa, 1e-6)
    out[..., 3] = oa
    return out


def resize(img, size):
    """Linear-light, premultiplied Lanczos."""
    lin = to_lin(img[..., :3]) * img[..., 3:4]
    chans = [Image.fromarray(lin[..., k]).resize((size, size), Image.LANCZOS) for k in range(3)]
    a = np.clip(np.asarray(Image.fromarray(img[..., 3]).resize((size, size), Image.LANCZOS)), 0, 1)
    rgb = np.stack([np.asarray(c) for c in chans], -1) / np.maximum(a[..., None], 1e-6)
    return np.concatenate([to_srgb(rgb), a[..., None]], -1).astype(np.float32)


def save(arr, path):
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path, optimize=True)
