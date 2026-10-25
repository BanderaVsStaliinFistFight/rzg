#!/usr/bin/env python3
"""Generates the throne room's textures into textures/ (needs numpy and Pillow).

Every surface texture tiles seamlessly and comes as a PBR set: <name>_color.png,
<name>_normal.png (OpenGL convention, green up, as Roblox expects), <name>_roughness.png
and, for gold, <name>_metalness.png. Colour maps are light and nearly neutral because
Roblox tints a MaterialVariant's colour map with the part's Color, so the builder's palette
still sets the hue. The *_card.png files are transparent cut-outs (ivy, grass, grime,
glass streaks) for Decals and Textures.

    python3 tools/make_textures.py            # all textures
    python3 tools/make_textures.py plaster    # just the named ones
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "textures"


# --- tileable building blocks ---------------------------------------------------------------


def spectral(n, rng, beta, fmin=0.0, fmax=0.5, stretch=(1.0, 1.0), angle=0.0):
    """Tileable fractal noise from filtered white noise, normalised to 0..1. `stretch`
    elongates features along x and y (before rotating by `angle`)."""
    fy = np.fft.fftfreq(n)[:, None]
    fx = np.fft.fftfreq(n)[None, :]
    c, s = math.cos(angle), math.sin(angle)
    u = (fx * c + fy * s) * stretch[0]
    v = (-fx * s + fy * c) * stretch[1]  # a big factor keeps only slow change that way
    f = np.sqrt(u * u + v * v)
    f[0, 0] = 1.0
    amp = f ** (-beta / 2.0)
    amp[(f < fmin) | (f > fmax)] = 0.0
    amp[0, 0] = 0.0
    field = np.real(np.fft.ifft2(np.fft.fft2(rng.standard_normal((n, n))) * amp))
    lo, hi = np.percentile(field, [0.5, 99.5])
    return np.clip((field - lo) / (hi - lo + 1e-9), 0.0, 1.0)


def worley(n, cells, rng, jitter=1.0):
    """Tileable cellular noise: distances to the nearest and second nearest feature
    points (in cell units) and the id of the nearest cell."""
    pts = 0.5 + (rng.random((cells, cells, 2)) - 0.5) * jitter
    y, x = np.mgrid[0:n, 0:n].astype(np.float64) * (cells / n)
    cx, cy = np.floor(x).astype(int), np.floor(y).astype(int)
    d1 = np.full((n, n), 9.0)
    d2 = np.full((n, n), 9.0)
    ids = np.zeros((n, n), dtype=int)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            gx, gy = cx + dx, cy + dy
            wx, wy = gx % cells, gy % cells
            px = gx + pts[wy, wx, 0]
            py = gy + pts[wy, wx, 1]
            d = np.sqrt((x - px) ** 2 + (y - py) ** 2)
            closer = d < d1
            d2 = np.where(closer, d1, np.minimum(d2, d))
            ids = np.where(closer, wy * cells + wx, ids)
            d1 = np.where(closer, d, d1)
    return d1, d2, ids


def blur(a, radius):
    """Tileable box-ish blur (three passes of a wrapped moving average)."""
    r = max(1, int(radius))
    for _ in range(3):
        acc = np.zeros_like(a)
        for k in range(-r, r + 1):
            acc += np.roll(a, k, axis=0)
        a = acc / (2 * r + 1)
        acc = np.zeros_like(a)
        for k in range(-r, r + 1):
            acc += np.roll(a, k, axis=1)
        a = acc / (2 * r + 1)
    return a


def normal_map(height, strength):
    """OpenGL-style normal map (green points up the texture) from a tileable height field."""
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx, ny, nz = -dx * strength, dy * strength, np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / length, ny / length, nz / length], axis=-1) * 0.5 + 0.5


def tileable_canvas(n, scale=1):
    """A 3x3 canvas so shapes drawn near an edge wrap around; crop with wrap_crop."""
    return Image.new("RGBA", (3 * n * scale, 3 * n * scale), (0, 0, 0, 0))


def wrap_crop(img, n, scale=1):
    """Fold a 3x3 canvas back into one seamless n x n tile."""
    big = np.asarray(img).astype(np.float64) / 255.0
    m = n * scale
    tile = np.zeros((m, m, big.shape[2]))
    for i in range(3):
        for j in range(3):
            part = big[i * m:(i + 1) * m, j * m:(j + 1) * m]
            a = part[..., 3:4]
            tile[..., :3] = tile[..., :3] * (1 - a) + part[..., :3] * a
            tile[..., 3:4] = tile[..., 3:4] + a * (1 - tile[..., 3:4])
    out = Image.fromarray((np.clip(tile, 0, 1) * 255).astype(np.uint8), "RGBA")
    return out.resize((n, n), Image.LANCZOS) if scale > 1 else out


def neutral(rgb, mean, keep):
    """Mostly grey version of `rgb` with the given mean brightness, keeping `keep` of its
    colour, so the part's Color can supply the hue."""
    lum = rgb.mean(axis=-1, keepdims=True)
    out = lum + keep * (rgb - lum)
    return out * (mean / max(1e-6, float(lum.mean())))


def save_rgb(name, rgb):
    Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(OUT / name, optimize=True)


def save_gray(name, gray):
    Image.fromarray((np.clip(gray, 0, 1) * 255 + 0.5).astype(np.uint8), "L").save(OUT / name, optimize=True)


def save_set(name, color, height, rough, strength, metal=None, mean=0.93):
    # Roblox multiplies the colour map by the part's Color, so keep the map bright: its
    # average sets how much darker than the part colour the surface ends up.
    color = color * (mean / float(color.mean()))
    save_rgb(f"{name}_color.png", color)
    save_rgb(f"{name}_normal.png", normal_map(height, strength))
    save_gray(f"{name}_roughness.png", rough)
    if metal is not None:
        save_gray(f"{name}_metalness.png", metal)


# --- surfaces -------------------------------------------------------------------------------


def plaster(n=1024):
    rng = np.random.default_rng(11)
    broad = spectral(n, rng, 3.2, fmax=0.02)
    mottle = spectral(n, rng, 2.4, fmin=0.004, fmax=0.08)
    grain = spectral(n, rng, 0.6, fmin=0.15)
    strokes = np.zeros((n, n))
    for k in range(4):  # trowel strokes in a few directions, each fading in and out
        layer = spectral(n, rng, 2.0, fmin=0.01, fmax=0.2, stretch=(5.0, 1.0), angle=rng.uniform(0, math.pi))
        mask = spectral(n, rng, 3.0, fmax=0.02)
        strokes += (layer - 0.5) * np.clip(mask * 2 - 0.6, 0, 1)
    d1, d2, _ = worley(n, 9, rng)
    crack = np.clip(1 - (d2 - d1) / 0.035, 0, 1) ** 2
    crack *= np.clip(spectral(n, rng, 3.0, fmax=0.03) * 3 - 1.9, 0, 1)  # only in a few places
    height = 0.6 * broad + 0.35 * strokes + 0.08 * grain - 0.5 * crack
    shade = 0.84 + 0.10 * (mottle - 0.5) + 0.06 * (broad - 0.5) + 0.05 * strokes + 0.03 * (grain - 0.5)
    shade -= 0.28 * crack
    warm = np.stack([np.ones_like(shade), 0.985 - 0.02 * mottle, 0.95 - 0.05 * mottle], axis=-1)
    color = shade[..., None] * warm
    rough = 0.82 + 0.08 * (grain - 0.5) - 0.08 * np.clip(strokes, 0, None) + 0.1 * crack
    save_set("plaster", color, height, rough, 3.0)


def sandstone(n=512):
    rng = np.random.default_rng(12)
    grain = spectral(n, rng, 0.4, fmin=0.12)
    bands = spectral(n, rng, 2.6, fmax=0.12, stretch=(8.0, 1.0))
    blotch = spectral(n, rng, 2.4, fmax=0.05)
    d1, _, _ = worley(n, 40, rng)
    pores = np.clip(1 - d1 / 0.18, 0, 1) ** 3 * (spectral(n, rng, 1.0, fmax=0.4) > 0.55)
    height = 0.5 * bands + 0.35 * grain - 0.6 * pores + 0.2 * blotch
    shade = 0.86 + 0.08 * (bands - 0.5) + 0.07 * (grain - 0.5) + 0.06 * (blotch - 0.5) - 0.25 * pores
    color = shade[..., None] * np.array([1.0, 0.97, 0.9])[None, None, :]
    rough = 0.9 + 0.06 * (grain - 0.5)
    save_set("sandstone", color, height, rough, 5.0)


def wood(n=1024, planks=True):
    rng = np.random.default_rng(13 if planks else 14)
    y, x = np.mgrid[0:n, 0:n].astype(np.float64) / n
    rows = 4 if planks else 1
    row = np.floor(y * rows).astype(int)
    v = y * rows - row  # 0..1 across a plank
    warp = spectral(n, rng, 2.8, fmax=0.05, stretch=(6.0, 1.0))
    fibers = spectral(n, rng, 1.0, fmin=0.02, stretch=(30.0, 1.0))
    rings = np.sin((v * (3 + 2 * rng.random()) + warp * 1.6) * 2 * math.pi)
    grain = 0.5 + 0.5 * rings
    grain = grain ** 2.2
    plank_shade = np.zeros((n, n))
    seam = np.zeros((n, n))
    if planks:
        for r in range(rows):
            in_row = row == r
            plank_shade += in_row * rng.uniform(-0.07, 0.07)
            for cut in rng.uniform(0, 1, 2) if r % 2 else rng.uniform(0, 1, 1):
                dist = np.abs(((x - cut + 0.5) % 1.0) - 0.5) * n
                seam = np.maximum(seam, in_row * np.clip(1 - dist / 2.5, 0, 1))
        edge = np.minimum(v, 1 - v) * n / rows
        seam = np.maximum(seam, np.clip(1 - edge / 2.5, 0, 1))
    knots_d, _, _ = worley(n, 5, rng)
    knot = np.clip(1 - knots_d / 0.12, 0, 1) ** 2 * (rng.random() > -1)
    shade = 0.78 + 0.12 * (fibers - 0.5) - 0.16 * grain + plank_shade - 0.18 * knot
    shade -= 0.5 * seam
    color = shade[..., None] * np.array([1.0, 0.93, 0.84])[None, None, :]
    height = 0.4 * fibers - 0.25 * grain - 1.2 * seam - 0.2 * knot
    rough = 0.6 + 0.12 * grain + 0.06 * (fibers - 0.5) + 0.3 * seam
    save_set("woodplanks" if planks else "wood", color, height, rough, 5.0)


def gold(n=512):
    rng = np.random.default_rng(15)
    brushed = spectral(n, rng, 1.2, fmin=0.01, stretch=(40.0, 1.0))
    smudge = spectral(n, rng, 2.8, fmax=0.04)
    canvas = tileable_canvas(n)
    draw = ImageDraw.Draw(canvas)
    for _ in range(160):  # fine scratches
        x0, y0 = rng.uniform(n, 2 * n, 2)
        ang = rng.uniform(0, math.pi)
        length = rng.uniform(10, 90)
        draw.line([(x0, y0), (x0 + math.cos(ang) * length, y0 + math.sin(ang) * length)],
                  fill=(255, 255, 255, int(rng.uniform(60, 160))), width=1)
    scratches = wrap_crop(canvas, n)
    scratch = np.asarray(scratches).astype(np.float64)[..., 3] / 255.0
    shade = 0.9 + 0.05 * (brushed - 0.5) - 0.06 * (smudge - 0.5) + 0.05 * scratch
    color = shade[..., None] * np.array([1.0, 0.97, 0.9])[None, None, :]
    height = 0.3 * brushed - 0.5 * scratch
    rough = 0.3 + 0.12 * (smudge - 0.5) + 0.08 * (brushed - 0.5) + 0.12 * scratch
    save_set("gold", color, height, rough, 2.0, metal=np.ones((n, n)))


def velvet(n=512):
    rng = np.random.default_rng(16)
    pile = spectral(n, rng, 0.2, fmin=0.2)
    crush = spectral(n, rng, 2.6, fmax=0.05)
    direction = spectral(n, rng, 1.8, fmin=0.01, fmax=0.1, stretch=(3.0, 1.0), angle=0.7)
    shade = 0.82 + 0.16 * (crush - 0.5) + 0.07 * (direction - 0.5) + 0.05 * (pile - 0.5)
    color = shade[..., None] * np.array([1.0, 0.98, 1.0])[None, None, :]
    height = 0.3 * crush + 0.2 * direction + 0.1 * pile
    rough = 0.92 + 0.05 * (pile - 0.5)
    save_set("velvet", color, height, rough, 3.0)


def linen(n=512):
    rng = np.random.default_rng(17)
    y, x = np.mgrid[0:n, 0:n].astype(np.float64)
    threads = 64
    jitter_x = spectral(n, rng, 2.0, fmax=0.1) * 0.6
    jitter_y = spectral(n, rng, 2.0, fmax=0.1) * 0.6
    warp = 0.5 + 0.5 * np.cos(2 * math.pi * (x / n * threads + jitter_x))
    weft = 0.5 + 0.5 * np.cos(2 * math.pi * (y / n * threads + jitter_y))
    over = (np.floor(x / n * threads) + np.floor(y / n * threads)) % 2
    weave = np.where(over > 0, warp, weft)
    slub = spectral(n, rng, 1.5, fmin=0.01, stretch=(20.0, 1.0))
    wrinkle = spectral(n, rng, 3.0, fmax=0.03)
    ridges = 1 - np.abs(spectral(n, rng, 2.6, fmax=0.04) * 2 - 1)
    shade = 0.9 + 0.05 * (weave - 0.5) + 0.04 * (slub - 0.5) - 0.06 * (1 - ridges) * wrinkle
    color = shade[..., None] * np.array([1.0, 1.0, 0.985])[None, None, :]
    height = 0.15 * weave + 0.1 * slub + 1.2 * ridges * wrinkle
    rough = 0.9 + 0.04 * (weave - 0.5)
    save_set("linen", color, height, rough, 3.0)


def terracotta(n=512):
    rng = np.random.default_rng(18)
    blotch = spectral(n, rng, 2.6, fmax=0.06)
    grain = spectral(n, rng, 0.5, fmin=0.1)
    d1, _, _ = worley(n, 26, rng)
    pits = np.clip(1 - d1 / 0.16, 0, 1) ** 3 * (spectral(n, rng, 1.0, fmax=0.3) > 0.6)
    wear = spectral(n, rng, 2.2, fmin=0.01, fmax=0.12)
    canvas = tileable_canvas(n)
    draw = ImageDraw.Draw(canvas)
    for _ in range(40):
        x0, y0 = rng.uniform(n, 2 * n, 2)
        ang = rng.uniform(0, math.pi)
        length = rng.uniform(20, 140)
        draw.line([(x0, y0), (x0 + math.cos(ang) * length, y0 + math.sin(ang) * length)],
                  fill=(255, 255, 255, int(rng.uniform(40, 110))), width=1)
    scratch = np.asarray(wrap_crop(canvas, n)).astype(np.float64)[..., 3] / 255.0
    shade = 0.84 + 0.12 * (blotch - 0.5) + 0.06 * (grain - 0.5) + 0.08 * (wear - 0.5) - 0.3 * pits + 0.06 * scratch
    color = np.stack([shade, shade * (0.97 + 0.03 * blotch), shade * (0.93 + 0.05 * wear)], axis=-1)
    height = 0.3 * wear + 0.2 * grain - 0.8 * pits - 0.3 * scratch
    rough = 0.72 + 0.1 * (grain - 0.5) - 0.12 * wear + 0.15 * pits
    save_set("terracotta", color, height, rough, 4.0)


def limestone(n=512):
    rng = np.random.default_rng(19)
    cloud = spectral(n, rng, 2.8, fmax=0.05)
    grain = spectral(n, rng, 0.5, fmin=0.12)
    d1, d2, _ = worley(n, 30, rng)
    fossils = np.clip(1 - d1 / 0.1, 0, 1) * (spectral(n, rng, 1.0, fmax=0.3) > 0.62)
    vein = np.clip(1 - np.abs(spectral(n, rng, 2.4, fmax=0.06) - 0.5) / 0.012, 0, 1)
    vein *= spectral(n, rng, 3.0, fmax=0.02) > 0.55
    d1b, _, _ = worley(n, 70, rng)
    pits = np.clip(1 - d1b / 0.12, 0, 1) ** 3 * (spectral(n, rng, 1.0, fmax=0.4) > 0.5)
    shade = 0.82 + 0.1 * (cloud - 0.5) + 0.06 * (grain - 0.5) + 0.05 * fossils - 0.12 * vein - 0.22 * pits
    color = shade[..., None] * np.array([1.0, 0.99, 0.965])[None, None, :]
    height = 0.4 * cloud + 0.25 * grain + 0.15 * fossils - 0.7 * pits
    rough = 0.8 + 0.08 * (grain - 0.5) + 0.1 * pits
    save_set("limestone", color, height, rough, 4.0)


def soil(n=512):
    rng = np.random.default_rng(20)
    d1, d2, ids = worley(n, 18, rng)
    clods = np.clip(d2 - d1, 0, 0.5) * 2
    fine = spectral(n, rng, 0.8, fmin=0.08)
    broad = spectral(n, rng, 2.6, fmax=0.05)
    p1, _, pid = worley(n, 34, rng)
    pebble_on = (np.sin(pid * 12.9898) * 43758.5453 % 1.0) > 0.78
    pebble = np.clip(1 - p1 / 0.32, 0, 1) ** 0.6 * pebble_on
    shade = 0.7 + 0.12 * (fine - 0.5) + 0.1 * (broad - 0.5) + 0.12 * clods + 0.3 * pebble
    color = np.stack([shade, shade * 0.97, shade * (0.92 + 0.08 * pebble)], axis=-1)
    height = 0.5 * clods + 0.25 * fine + 0.9 * pebble + 0.2 * broad
    rough = 0.95 - 0.25 * pebble
    save_set("soil", color, height, rough, 6.0, mean=0.85)


def grass_ground(n=512):
    rng = np.random.default_rng(21)
    scale = 2
    canvas = tileable_canvas(n, scale)
    draw = ImageDraw.Draw(canvas)
    m = n * scale
    base = spectral(n, rng, 2.6, fmax=0.05)
    for i in range(7000):
        x0, y0 = rng.uniform(m, 2 * m, 2)
        ang = rng.normal(-math.pi / 2, 0.9)
        length = rng.uniform(10, 34) * scale / 2
        g = rng.uniform(0.45, 1.0)
        col = (int(255 * g * rng.uniform(0.75, 0.95)), int(255 * g), int(255 * g * rng.uniform(0.6, 0.85)), 255)
        draw.line([(x0, y0), (x0 + math.cos(ang) * length, y0 + math.sin(ang) * length)], fill=col, width=scale + 1)
    blades = np.asarray(wrap_crop(canvas, n, scale)).astype(np.float64) / 255.0
    lum = blades[..., :3].mean(axis=-1)
    under = 0.35 + 0.2 * base
    cover = blades[..., 3]
    color = blades[..., :3] * cover[..., None] + (under * (1 - cover))[..., None] * np.array([0.9, 1.0, 0.8])
    color *= (0.85 + 0.25 * (base - 0.5))[..., None]
    color = neutral(color, 0.85, 0.3)
    height = lum * cover * 0.8 + 0.2 * base
    rough = 0.8 + 0.1 * (1 - cover)
    save_set("grass", color, height, rough, 5.0)


def leaf_shape(draw, cx, cy, length, width, angle, fill, vein=None):
    """An almond-shaped leaf with a midrib."""
    pts = []
    for i in range(24):
        t = i / 23
        w = math.sin(math.pi * t) ** 0.8 * width / 2
        pts.append((t * length - length / 2, w))
    for i in range(23, -1, -1):
        t = i / 23
        w = math.sin(math.pi * t) ** 0.8 * width / 2
        pts.append((t * length - length / 2, -w))
    c, s = math.cos(angle), math.sin(angle)
    poly = [(cx + px * c - py * s, cy + px * s + py * c) for px, py in pts]
    draw.polygon(poly, fill=fill)
    if vein:
        draw.line([poly[0], poly[23]], fill=vein, width=1)


def leaves(n=512):
    rng = np.random.default_rng(23)
    scale = 2
    m = n * scale
    canvas = tileable_canvas(n, scale)
    draw = ImageDraw.Draw(canvas)
    for i in range(1400):
        x0, y0 = rng.uniform(m, 2 * m, 2)
        length = rng.uniform(28, 64) * scale / 2
        g = rng.uniform(0.5, 1.0) * (0.75 + 0.25 * i / 1400)  # later (upper) leaves are lighter
        col = (int(255 * g * rng.uniform(0.7, 0.9)), int(255 * g), int(255 * g * rng.uniform(0.55, 0.8)), 255)
        vein = tuple(min(255, int(v * 1.25)) for v in col[:3]) + (255,)
        leaf_shape(draw, x0, y0, length, length * rng.uniform(0.38, 0.55), rng.uniform(0, math.pi * 2), col, vein)
    img = wrap_crop(canvas, n, scale)
    rgba = np.asarray(img).astype(np.float64) / 255.0
    color = rgba[..., :3] * rgba[..., 3:4] + 0.32 * (1 - rgba[..., 3:4])
    lum = color.mean(axis=-1)
    height = blur(lum, 1) * 1.0
    ao = blur(lum, 6)
    color *= (0.85 + 0.2 * ao)[..., None]
    color = neutral(color, 0.8, 0.3)
    rough = 0.65 + 0.2 * (1 - lum)
    save_set("leaves", color, height, rough, 6.0)


# --- cut-out cards (RGBA) -------------------------------------------------------------------


def ivy_leaf_polygon(cx, cy, size, angle):
    """A five-lobed ivy leaf (Hedera helix), pointing along `angle`."""
    lobes = [(0.0, 1.0), (0.95, 0.72), (-0.95, 0.72), (1.9, 0.5), (-1.9, 0.5)]
    pts = []
    steps = 90
    for i in range(steps):
        th = -math.pi + 2 * math.pi * i / steps
        r = 0.42
        for la, lr in lobes:
            d = math.atan2(math.sin(th - la), math.cos(th - la))
            r += (lr - 0.42) * math.exp(-(d / 0.42) ** 2)
        if abs(abs(th) - math.pi) < 0.35:  # the notch where the stalk joins
            r *= 0.55 + 0.45 * (abs(abs(th) - math.pi) / 0.35)
        px, py = r * math.cos(th) * size, r * math.sin(th) * size
        c, s = math.cos(angle), math.sin(angle)
        pts.append((cx + px * c - py * s, cy + px * s + py * c))
    tips = []
    for la, lr in lobes:
        px, py = lr * math.cos(la) * size, lr * math.sin(la) * size
        c, s = math.cos(angle), math.sin(angle)
        tips.append((cx + px * c - py * s, cy + px * s + py * c))
    return pts, tips


def ivy_card(n=1024):
    rng = np.random.default_rng(31)
    s = 2
    img = Image.new("RGBA", (n * s, n * s), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (n * s, n * s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    sdraw = ImageDraw.Draw(shadow)
    # two meandering stems across the card
    stems = []
    for k in range(2):
        pts = []
        x, y = rng.uniform(0.25, 0.75) * n * s, -0.05 * n * s
        ang = math.pi / 2 + rng.uniform(-0.3, 0.3)
        while 0 - 0.1 * n * s < y < 1.1 * n * s:
            pts.append((x, y))
            ang += rng.uniform(-0.25, 0.25)
            ang = min(max(ang, math.pi / 2 - 0.6), math.pi / 2 + 0.6)
            x += math.cos(ang) * 22 * s
            y += math.sin(ang) * 22 * s
        stems.append(pts)
        draw.line(pts, fill=(88, 70, 44, 255), width=5 * s, joint="curve")
    leaves_drawn = []
    for pts in stems:
        for i in range(1, len(pts) - 1, 2):
            px, py = pts[i]
            for side in (-1, 1):
                if rng.random() < 0.1:
                    continue
                stalk = rng.uniform(30, 70) * s
                ang = math.atan2(pts[i + 1][1] - py, pts[i + 1][0] - px) + side * rng.uniform(0.9, 1.6)
                lx, ly = px + math.cos(ang) * stalk, py + math.sin(ang) * stalk
                if not (0.12 * n * s < lx < 0.88 * n * s and 0.08 * n * s < ly < 0.92 * n * s):
                    continue
                draw.line([(px, py), (lx, ly)], fill=(96, 92, 46, 255), width=3 * s)
                size = rng.uniform(85, 135) * s
                leaves_drawn.append((lx + math.cos(ang) * size * 0.4, ly + math.sin(ang) * size * 0.4, size,
                                     ang + rng.uniform(-0.5, 0.5)))
    rng.shuffle(leaves_drawn)
    for cx, cy, size, ang in leaves_drawn:
        poly, tips = ivy_leaf_polygon(cx, cy, size, ang)
        sdraw.polygon([(x + 10 * s, y + 14 * s) for x, y in poly], fill=(0, 0, 0, 120))
        g = rng.uniform(0.75, 1.15)
        base = (int(46 * g), int(96 * g), int(44 * g), 255)
        draw.polygon(poly, fill=base)
        # lighter toward the middle, and pale veins from the stalk to each lobe tip
        inner, _ = ivy_leaf_polygon(cx, cy, size * 0.62, ang)
        draw.polygon(inner, fill=(int(base[0] * 1.12), int(base[1] * 1.12), int(base[2] * 1.08), 255))
        stalk_x = cx - math.cos(ang) * size * 0.25
        stalk_y = cy - math.sin(ang) * size * 0.25
        for tx, ty in tips:
            draw.line([(stalk_x, stalk_y), (tx * 0.9 + stalk_x * 0.1, ty * 0.9 + stalk_y * 0.1)],
                      fill=(150, 176, 118, 255), width=max(1, int(2 * s)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(10 * s))
    out = Image.alpha_composite(shadow, img).resize((n, n), Image.LANCZOS)
    out.save(OUT / "ivy_card.png", optimize=True)


def blade(draw, rng, root_x, root_y, height, width, lean, color, tip_light=1.15, segments=14):
    """A curved, tapering grass blade, dark at the root and lighter toward the tip."""
    pts = []
    for i in range(segments + 1):
        t = i / segments
        x = root_x + lean * height * t * t
        y = root_y - height * t * (1 - 0.18 * abs(lean) * t)
        pts.append((x, y, width * (1 - t) ** 0.85 / 2))
    for i in range(segments):
        (x0, y0, w0), (x1, y1, w1) = pts[i], pts[i + 1]
        t = (i + 0.5) / segments
        shade = 0.45 + (tip_light - 0.45) * t ** 0.7
        col = tuple(min(255, int(c * shade)) for c in color) + (255,)
        dx, dy = x1 - x0, y1 - y0
        length = math.hypot(dx, dy) or 1
        nx, ny = -dy / length, dx / length
        draw.polygon([(x0 + nx * w0, y0 + ny * w0), (x1 + nx * w1, y1 + ny * w1),
                      (x1 - nx * w1, y1 - ny * w1), (x0 - nx * w0, y0 - ny * w0)], fill=col)
    if width > 9:  # a pale midrib on the broader blades
        mid = [(x, y) for x, y, _ in pts[: segments - 2]]
        draw.line(mid, fill=tuple(min(255, int(c * 1.25)) for c in color) + (150,), width=2)


GREENS = [(70, 130, 48), (84, 140, 52), (58, 116, 42), (96, 146, 60), (66, 122, 56)]
STRAW = [(160, 150, 86), (176, 160, 96), (140, 128, 72)]


def grass_card(n=512):
    """A dense tuft: broad curved blades, a few gone dry."""
    rng = np.random.default_rng(32)
    s = 2
    img = Image.new("RGBA", (n * s, n * s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for i in range(170):
        dry = rng.random() < 0.08
        color = STRAW[rng.integers(len(STRAW))] if dry else GREENS[rng.integers(len(GREENS))]
        color = tuple(int(c * rng.uniform(0.8, 1.1)) for c in color)
        blade(draw, rng, n * s * (0.5 + rng.normal(0, 0.13)), n * s * 1.02, n * s * rng.uniform(0.35, 0.95),
              rng.uniform(6, 14) * s, rng.normal(0, 0.38), color)
    img.resize((n, n), Image.LANCZOS).save(OUT / "grass_card.png", optimize=True)


def tallgrass_card(n=512):
    """Wispy meadow grass going to seed: thin blades and a few stems with seed heads."""
    rng = np.random.default_rng(35)
    s = 2
    img = Image.new("RGBA", (n * s, n * s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for i in range(110):
        dry = rng.random() < 0.12
        color = STRAW[rng.integers(len(STRAW))] if dry else GREENS[rng.integers(len(GREENS))]
        blade(draw, rng, n * s * (0.5 + rng.normal(0, 0.1)), n * s * 1.02, n * s * rng.uniform(0.3, 0.75),
              rng.uniform(4, 8) * s, rng.normal(0, 0.5), color)
    for i in range(11):  # seeding stems
        x0 = n * s * (0.5 + rng.normal(0, 0.1))
        height = n * s * rng.uniform(0.7, 0.97)
        lean = rng.normal(0, 0.25)
        stem = [(x0 + lean * height * t * t, n * s * 1.02 - height * t) for t in np.linspace(0, 1, 16)]
        draw.line(stem, fill=(118, 132, 64, 255), width=int(2.5 * s), joint="curve")
        tan = STRAW[rng.integers(len(STRAW))]
        for t in np.linspace(0.62, 1.0, 16):  # spikelets along the top of the stem
            k = min(15, int(t * 15))
            x, y = stem[k]
            for side in (-1, 1):
                ang = -math.pi / 2 + side * rng.uniform(0.25, 0.7)
                length = rng.uniform(22, 36) * s * (1.25 - t)
                cx, cy = x + math.cos(ang) * length / 2, y + math.sin(ang) * length / 2
                leaf_shape(draw, cx, cy, length, length * 0.42, ang, tan + (255,))
    img.resize((n, n), Image.LANCZOS).save(OUT / "tallgrass_card.png", optimize=True)


def grime_card(n=512):
    """Dust and soot for the foot of a wall: dark at the bottom edge, with drips. Tiles
    left to right."""
    rng = np.random.default_rng(33)
    y, x = np.mgrid[0:n, 0:n].astype(np.float64) / n
    cloud = spectral(n, rng, 2.4, fmax=0.06)
    drips = spectral(n, rng, 1.6, fmin=0.01, fmax=0.2, stretch=(1.0, 25.0))
    fade = np.clip(y, 0, 1) ** 2.2
    alpha = fade * (0.45 + 0.4 * cloud) + 0.18 * np.clip(drips * 2 - 1, 0, 1) * y
    alpha = np.clip(alpha, 0, 0.85)
    rgb = np.stack([0.24 + 0.05 * cloud, 0.2 + 0.04 * cloud, 0.14 + 0.03 * cloud], axis=-1)
    rgba = np.concatenate([rgb, alpha[..., None]], axis=-1)
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(OUT / "grime_card.png", optimize=True)


def glass_card(n=512):
    """Streaks and seed bubbles laid over the window glass."""
    rng = np.random.default_rng(34)
    streak = spectral(n, rng, 1.4, fmin=0.01, fmax=0.3, stretch=(1.0, 20.0))
    cloud = spectral(n, rng, 2.6, fmax=0.05)
    d1, _, _ = worley(n, 40, rng)
    seeds = np.clip(1 - d1 / 0.07, 0, 1) * (spectral(n, rng, 1.0, fmax=0.4) > 0.6)
    alpha = np.clip(0.06 + 0.22 * np.abs(streak - 0.5) * 2 + 0.12 * cloud + 0.5 * seeds, 0, 0.6)
    shade = 0.55 + 0.35 * cloud
    rgb = np.stack([shade, shade * 0.85, shade * 0.6], axis=-1)
    rgba = np.concatenate([rgb, alpha[..., None]], axis=-1)
    Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(OUT / "glass_card.png", optimize=True)


MAKERS = {
    "plaster": plaster,
    "sandstone": sandstone,
    "woodplanks": lambda: wood(planks=True),
    "wood": lambda: wood(n=512, planks=False),
    "gold": gold,
    "velvet": velvet,
    "linen": linen,
    "terracotta": terracotta,
    "limestone": limestone,
    "soil": soil,
    "grass": grass_ground,
    "leaves": leaves,
    "ivy_card": ivy_card,
    "grass_card": grass_card,
    "tallgrass_card": tallgrass_card,
    "grime_card": grime_card,
    "glass_card": glass_card,
}

if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    for name in sys.argv[1:] or MAKERS:
        MAKERS[name]()
        print("made", name)
