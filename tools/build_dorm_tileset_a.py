#!/usr/bin/env python3
"""Modular dorm tileset, variant A ("warm walnut + aged paper").

Builds assets/tilesets/dorm_a_atlas.png (32x32 grid), dorm_a_tiles.json (tile name -> atlas
coords/size) and dorm_test_layout.json (demo room + corridor) from the painted room canvas.

Seamlessness rule: every variant of a family is derived from ONE horizontally periodic base,
and details are painted strictly inside the tile, so any variant can sit next to any other.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TS = ROOT / "assets" / "tilesets"
T = 32
OUTLINE = np.array([20, 15, 15], float)

src = np.array(Image.open(TS / "boy_room_canvas.png").convert("RGB")).astype(float)
rng = np.random.default_rng(904)


# ---------------------------------------------------------------- helpers
def periodic_noise(h, w, seed, fmax=5, aniso=1.0):
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    acc = np.zeros((h, w))
    for fy in range(1, fmax + 1):
        for fx in range(1, fmax + 1):
            amp = 1.0 / ((fy * aniso) ** 2 + fx ** 2) ** 0.8
            acc += amp * np.sin(2 * np.pi * fy * yy / h + r.uniform(0, 6.28)) * \
                np.cos(2 * np.pi * fx * xx / w + r.uniform(0, 6.28))
    return (acc - acc.min()) / (acc.max() - acc.min())


def seamless_x(strip, w=T, overlap=12):
    out = strip[:, :w].copy()
    for x in range(overlap):
        t = 0.5 - 0.5 * np.cos(np.pi * (x + 1) / (overlap + 1))
        out[:, x] = (1 - t) * strip[:, w + x] + t * strip[:, x]
    return out


def match_mean(arr, target):
    return arr - arr.reshape(-1, 3).mean(0) + np.asarray(target, float)


def blob(h, w, cy, cx, r, seed):
    """Irregular soft blob mask in [0,1]."""
    yy, xx = np.mgrid[0:h, 0:w]
    n = periodic_noise(h, w, seed, 4)
    d = np.sqrt(((yy - cy) / r) ** 2 + ((xx - cx) / (r * 1.15)) ** 2) + (n - 0.5) * 0.7
    return np.clip(1.0 - d, 0, 1)


def clamp(a):
    return np.clip(a, 0, 255)


# ------------------------------------------------- 1. wall band 96 px tall
# Source wall: y=12..103 (cornice 12-17, paper 18-95, baseboard 96-103) -> stretch to 96 rows
rows = list(range(12, 104))
for dup in (75, 60, 45, 30):          # duplicate wallpaper rows, keep cornice/baseboard crisp
    rows.insert(rows.index(dup), dup)
band = src[rows]                       # (96, 344, 3)
assert band.shape[0] == 96

room_wall_base = seamless_x(band[:, 150:200])
room_wall_base = clamp(room_wall_base)

# wallpaper reference per row (for object detection: window / door)
row_ref = np.median(band[:, 150:200], axis=1)


def object_bbox(x0, x1, y0=6, y1=96, thr=30, frac=0.75):
    """Tight bbox: keep only columns/rows that are mostly 'not wallpaper'."""
    diff = np.abs(band[y0:y1, x0:x1] - row_ref[y0:y1, None]).mean(2)
    m = diff > thr
    cols = np.where(m.mean(0) >= frac)[0]
    cx0, cx1 = cols.min(), cols.max() + 1
    rws = np.where(m[:, cx0:cx1].mean(1) >= frac)[0]
    return y0 + rws.min(), y0 + rws.max() + 1, x0 + cx0, x0 + cx1


# ---------------------------------------------- 2. corridor wall (soviet two-tone)
def corridor_from(base):
    out = base.copy()
    lum = base.mean(2)
    detail = lum - lum.mean(1, keepdims=True)
    nz = periodic_noise(96, T, 31, 5, 0.5) - 0.5
    fine = periodic_noise(96, T, 37, 6) - 0.5
    for y in range(96):
        if y < 6:                                   # cornice: neutral dark trim
            out[y] = base[y].mean(1, keepdims=True) * np.array([0.95, 0.95, 0.88])
        elif y < 48:                                # whitewashed plaster, ceiling grime
            grime = max(0.0, 1 - (y - 6) / 14.0) * 26
            c = np.array([138, 130, 112]) - grime
            out[y] = c + detail[y, :, None] * 0.25 + nz[y, :, None] * 14 + fine[y, :, None] * 6
        elif y == 48:
            out[y] = [36, 42, 32]
        elif y == 49:
            out[y] = [96, 108, 82]
        elif y < 88:                                # olive oil paint, slight gloss toward top
            gloss = max(0.0, 1 - (y - 50) / 10.0) * 10
            c = np.array([78, 92, 66]) + gloss
            out[y] = c + nz[y, :, None] * 10 + fine[y, :, None] * 5
        else:                                       # painted baseboard
            by = y - 88
            c = np.array([44, 46, 36])
            if by == 0:
                c = OUTLINE + 6
            elif by == 1:
                c = np.array([70, 74, 58])
            elif by == 7:
                c = OUTLINE
            out[y] = c + fine[y, :, None] * 6
    return clamp(out)


corr_wall_base = corridor_from(room_wall_base)


# ---------------------------------------------------- 3. wall decals (inside tile only)
def water_stain(img, cy, cx, r, seed, tint=(-30, -34, -40)):
    m = blob(96, T, cy, cx, r, seed)
    rim = ((m > 0.02) & (m < 0.16)).astype(float)
    img += m[..., None] * np.array(tint) * 0.55
    img += rim[..., None] * np.array(tint) * 0.6
    return img


def peeled(img, cy, cx, r, seed, under=(150, 140, 120)):
    m = blob(96, T, cy, cx, r, seed) > 0.22
    edge = m ^ np.pad(m, 1, mode="edge")[2:, 1:-1]
    img[m] = np.array(under) + (periodic_noise(96, T, seed + 1)[m][:, None] - 0.5) * 16
    img[edge] = img[edge] * 0.55
    return img


def crack(img, y0, x0, length, seed):
    r = np.random.default_rng(seed)
    y, x = y0, x0
    for _ in range(length):
        if 0 <= y < 96 and 1 <= x < T - 1:
            img[y, x] = img[y, x] * 0.55
            img[y, x + 1] = img[y, x + 1] * 1.08
        y += 1
        x += r.choice([-1, 0, 0, 1])
    return img


def score_sheet(img, y0, x0, w=12, h=15):
    img[y0 + 1:y0 + h + 1, x0 + 1:x0 + w + 1] *= 0.7               # drop shadow
    paper = np.array([182, 168, 142])
    img[y0:y0 + h, x0:x0 + w] = paper
    img[y0:y0 + h, x0 + w - 1] = paper * 0.86
    for sy in range(y0 + 3, y0 + h - 2, 2):
        if (sy - y0) % 6 != 1:
            img[sy, x0 + 2:x0 + w - 2] = [104, 90, 76]
    for nx, ny in ((x0 + 4, y0 + 4), (x0 + 7, y0 + 6), (x0 + 5, y0 + 10)):
        img[ny, nx] = [40, 32, 28]
    img[y0 + 1, x0 + w // 2] = [150, 40, 36]                          # red pin
    return img


def notice(img, y0, x0, w=14, h=17):
    img[y0 + 1:y0 + h + 1, x0 + 1:x0 + w + 1] *= 0.72
    img[y0:y0 + h, x0:x0 + w] = [196, 190, 172]
    img[y0 + 2, x0 + 3:x0 + w - 3] = [60, 54, 50]                     # title
    for sy in range(y0 + 5, y0 + h - 2, 2):
        ln = w - 4 - (sy * 7 % 5)
        img[sy, x0 + 2:x0 + 2 + ln] = [128, 122, 112]
    img[y0 - 1:y0 + 1, x0 + 1:x0 + 4] = [176, 168, 128]               # tape
    img[y0 - 1:y0 + 1, x0 + w - 4:x0 + w - 1] = [176, 168, 128]
    return img


def socket(img, y0, x0):
    img[y0:y0 + 7, x0:x0 + 7] = [168, 160, 142]
    img[y0 + 6, x0:x0 + 7] = [96, 90, 80]
    img[y0:y0 + 7, x0 + 6] = [110, 104, 92]
    img[y0 + 3, x0 + 2] = img[y0 + 3, x0 + 4] = [40, 34, 30]
    return img


def radiator(img, y0, x0, w=26, h=18):
    iron = np.array([116, 112, 100])
    img[y0 + h, x0 + 1:x0 + w + 1] *= 0.62                              # floor/wall shadow
    for i in range(0, w, 3):
        img[y0:y0 + h, x0 + i] = iron * 1.12
        img[y0:y0 + h, x0 + i + 1] = iron
        img[y0:y0 + h, x0 + i + 2] = iron * 0.6
    img[y0, x0:x0 + w] = iron * 1.25
    img[y0 + 2, x0:x0 + w] = iron * 0.8
    img[y0 + h - 3, x0:x0 + w] = iron * 0.8
    img[y0 - 1, x0:x0 + w] = OUTLINE + 10
    img[y0 + 4:y0 + 7, x0 - 3:x0] = [92, 88, 80]                        # pipe
    return img


def wall_variants(base, kind):
    v = [base.copy() for _ in range(4)]
    if kind == "room":
        water_stain(v[1], 14, 18, 8, 11)                     # stain under ceiling
        water_stain(v[1], 70, 10, 4, 12, (-14, -16, -18))
        peeled(v[2], 50, 15, 6, 21)                          # torn wallpaper shows plaster
        crack(v[2], 7, 22, 18, 23)
        score_sheet(v[3], 10, 9)                             # pinned page (top tile)
        socket(v[3], 76, 12)                                 # soviet socket (bottom tile)
    else:
        water_stain(v[1], 13, 14, 9, 41, (-26, -26, -30))
        peeled(v[2], 66, 17, 7, 51, (136, 128, 110))         # chipped olive paint
        crack(v[2], 20, 9, 22, 53)
        notice(v[3], 14, 9)                                  # "объявление"
        radiator(v[3], 66, 3)                                # cast-iron radiator
    return [clamp(x) for x in v]


room_walls = wall_variants(room_wall_base, "room")
corr_walls = wall_variants(corr_wall_base, "corr")

# ----------------------------------------------------------------- 4. floors
# Source planks: seams every 7 rows at y=124,131,138,145 -> stretch each plank to 8 rows
plank_rows = []
for s in (124, 131, 138, 145):
    r = list(range(s, s + 7))
    r.insert(4, s + 3)
    plank_rows += r
floor_strip = src[plank_rows, 240:292]
room_floor_base = seamless_x(floor_strip)
room_floor_base = match_mean(room_floor_base, [78, 55, 42])
fine = periodic_noise(T, T, 71, 6, 3.0) - 0.5
room_floor_base += fine[..., None] * 6
for p in range(4):                         # plank seams (shared by all variants)
    y = p * 8
    room_floor_base[y] = room_floor_base[y] * 0.58
    room_floor_base[y + 1] = room_floor_base[y + 1] * 1.05
room_floor_base = clamp(room_floor_base)
JOINTS = ((3, 21, 12, 28), (10, 26, 5, 19), (17, 2, 24, 9), (25, 13, 29, 6))


def add_joints(tile, xs):
    for p, jx in enumerate(xs):              # joints live inside the tile -> free per variant
        y = p * 8
        tile[y + 1:y + 8, jx] *= 0.68
        tile[y + 1:y + 8, jx + 1] *= 1.04
    return tile


def floor_room_variants(base):
    v = [add_joints(base.copy(), JOINTS[i]) for i in range(4)]
    # v[1]: subtle darker plank piece + tiny wood knot
    v[1][9:16, 22:31] = v[1][9:16, 22:31] * np.array([0.89, 0.85, 0.83])
    v[1][19, 7:9] = v[1][19, 7:9] * 0.74
    v[1][20, 8] = v[1][20, 8] * 0.82
    # v[2]: faint diagonal wood scuff / wear
    for i in range(10):
        v[2][20 + i // 4, 6 + i] *= 1.08
        v[2][4 + i // 5, 16 + i] *= 1.07
    # v[3]: subtle tonal plank variation + very soft organic wood grain streak (no circular bullseye)
    v[3][17:24, 3:18] = v[3][17:24, 3:18] * np.array([0.91, 0.88, 0.86])
    v[3][12:15, 11:25] = v[3][12:15, 11:25] * np.array([0.93, 0.91, 0.89])
    return [clamp(x) for x in v]


room_floors = floor_room_variants(room_floor_base)

# corridor: worn soviet linoleum with subtle warm-olive stone fleck + horizontal wear
n1 = periodic_noise(T, T, 91, 5)
n2 = periodic_noise(T, T, 97, 6)
tones = np.array([[72, 66, 56], [77, 70, 60], [82, 74, 64], [87, 79, 68]], float)
idx = np.clip((n1 * 0.65 + n2 * 0.35) * 3.99, 0, 3).astype(int)
corr_floor_base = tones[idx] + (n2[..., None] - 0.5) * 5
fl = np.random.default_rng(5)
for _ in range(36):
    y, x = fl.integers(0, T, 2)
    corr_floor_base[y, x] *= fl.choice([0.86, 1.10])
corr_floor_base = clamp(corr_floor_base)


def floor_corr_variants(base):
    v = [base.copy() for _ in range(4)]
    # v[1]: subtle welded linoleum seam at left edge
    v[1][:, 0] *= 0.72
    v[1][:, 1] *= 1.05
    # v[2]: gentle shoe scuffs
    for cy, cx, ln in ((9, 6, 7), (22, 17, 9)):
        v[2][cy, cx:cx + ln] *= 0.84
        v[2][cy + 1, cx + 2:cx + ln - 1] *= 0.90
    # v[3]: faint matte wear patch (no dark circular dots)
    m = blob(T, T, 15, 17, 7, 99)
    v[3] += m[..., None] * np.array([-11, -10, -9])
    v[3][21, 9:12] *= 0.86
    return [clamp(x) for x in v]


corr_floors = floor_corr_variants(corr_floor_base)


def with_wall_shadow(tile, depth=7):
    t = tile.copy()
    for y in range(depth):
        t[y] *= 0.52 + 0.48 * (y / depth) ** 0.8
    return clamp(t)


threshold = np.concatenate([room_floors[0][:, :16], corr_floors[0][:, 16:]], axis=1)
threshold[:, 12] = OUTLINE
threshold[:, 13:15] = [94, 66, 46]
threshold[:, 15:18] = [70, 48, 34]
threshold[:, 18] = [46, 32, 24]
threshold[:, 19] = OUTLINE + 4

# ---------------------------------------------------- 5. wall-top (cutaway) 16 masks
# bit 1 = rim on LEFT, 2 = RIGHT, 4 = TOP, 8 = BOTTOM (rim faces walkable floor)
walltop_base = np.array([28, 21, 19]) + (periodic_noise(T, T, 111, 4)[..., None] - 0.5) * 7


def walltop(mask):
    t = walltop_base.copy()
    light, mid = np.array([92, 64, 46]), np.array([60, 42, 31])
    if mask & 1:
        t[:, 0] = OUTLINE; t[:, 1:3] = light; t[:, 3] = mid
    if mask & 2:
        t[:, 31] = OUTLINE; t[:, 29:31] = light; t[:, 28] = mid
    if mask & 4:
        t[0] = OUTLINE; t[1:3] = light; t[3] = mid
    if mask & 8:                       # front face: thicker walnut edge seen in 3/4
        t[24] = mid * 0.9
        t[25:28] = light
        t[28:31] = np.array([70, 49, 35])
        t[31] = OUTLINE
    return clamp(t)


walltops = [walltop(m) for m in range(16)]
void = np.zeros((T, T, 3)) + np.array([14, 11, 11])

# ------------------------------------------------------------ 6. props (2x3)
DIGITS = {
    "0": ["111", "101", "101", "101", "111"], "4": ["101", "101", "111", "001", "001"],
    "5": ["111", "100", "111", "001", "111"], "9": ["111", "101", "111", "001", "111"],
}


def plaque(img, y0, x0, text):
    w = len(text) * 4 + 1
    img[y0 - 1:y0 + 7, x0 - 1:x0 + w + 1] = OUTLINE
    img[y0:y0 + 6, x0:x0 + w] = [186, 170, 138]
    img[y0 + 5, x0:x0 + w] = [140, 126, 100]
    for i, ch in enumerate(text):
        for ry, row in enumerate(DIGITS[ch]):
            for rx, bit in enumerate(row):
                if bit == "1" and ry < 5:
                    img[y0 + ry, x0 + 1 + i * 4 + rx] = [42, 32, 28]
    return img


dy0, dy1, dx0, dx1 = object_bbox(244, 306)
dy1 = 88                                   # door stands on the baseboard
wy0, wy1, wx0, wx1 = object_bbox(36, 108)
door = band[dy0:dy1, dx0:dx1]
window = band[wy0:wy1, wx0:wx1]


def prop(bg_tile, obj, oy, center=32):
    img = np.concatenate([bg_tile, bg_tile], axis=1).copy()
    ow = obj.shape[1]
    ox = max(0, center - ow // 2)
    ow = min(ow, 64 - ox)
    img[oy:oy + obj.shape[0], ox:ox + ow] = obj[:, :ow]
    return img, ox, ow


corr_door_904, ox, ow = prop(corr_walls[0], door, dy0)
plaque(corr_door_904, 30, min(63 - 13, ox + ow + 2) if ox + ow + 15 < 64 else 2, "904")
corr_door_905, ox, ow = prop(corr_walls[0], door, dy0)
plaque(corr_door_905, 30, min(63 - 13, ox + ow + 2) if ox + ow + 15 < 64 else 2, "905")
room_door, _, _ = prop(room_walls[0], door, dy0)
room_window, _, _ = prop(room_walls[0], window, wy0)
if wy1 + 20 < 88:
    radiator(room_window, 70, 19)
for p in (corr_door_904, corr_door_905, room_door, room_window):
    np.clip(p, 0, 255, out=p)

# ---------------------------------------------------------- 7. atlas assembly
COLS, ROWS = 8, 10
atlas = np.zeros((ROWS * T, COLS * T, 4), np.uint8)
tiles = {}


def put(name, img, col, row, size=(1, 1)):
    h, w = img.shape[:2]
    atlas[row * T:row * T + h, col * T:col * T + w, :3] = np.clip(img, 0, 255).astype(np.uint8)
    atlas[row * T:row * T + h, col * T:col * T + w, 3] = 255
    tiles[name] = {"atlas": [col, row], "size": list(size)}


for v in range(4):
    for part, (y0, row) in enumerate(((0, 0), (32, 1), (64, 2))):
        pname = ["top", "mid", "bot"][part]
        put(f"room_wall_{pname}_{v}", room_walls[v][y0:y0 + 32], v, row)
        put(f"corr_wall_{pname}_{v}", corr_walls[v][y0:y0 + 32], 4 + v, row)
    put(f"room_floor_{v}", room_floors[v], v, 3)
    put(f"corr_floor_{v}", corr_floors[v], 4 + v, 3)
put("room_floor_shadow_0", with_wall_shadow(room_floors[0]), 0, 4)
put("room_floor_shadow_1", with_wall_shadow(room_floors[1]), 1, 4)
put("corr_floor_shadow_0", with_wall_shadow(corr_floors[0]), 2, 4)
put("corr_floor_shadow_1", with_wall_shadow(corr_floors[2]), 3, 4)
put("threshold", threshold, 4, 4)
put("void", void, 5, 4)
for m in range(16):
    put(f"walltop_{m}", walltops[m], m % 8, 5 + m // 8)
put("corr_door_904", corr_door_904, 0, 7, (2, 3))
put("corr_door_905", corr_door_905, 2, 7, (2, 3))
put("room_window", room_window, 4, 7, (2, 3))
put("room_door", room_door, 6, 7, (2, 3))

Image.fromarray(atlas, "RGBA").save(TS / "dorm_a_atlas.png")
(TS / "dorm_a_tiles.json").write_text(json.dumps({"tile_size": T, "tiles": tiles}, indent=1))

# ---------------------------------------------------------- 8. demo layout
W, H = 22, 11
grid = [[None] * W for _ in range(H)]
solid = [[False] * W for _ in range(H)]
PART = 11


def is_wall(x, y):
    return x in (0, W - 1, PART) or y == H - 1


DOORWAY = (6, 7)
for y in range(H):
    for x in range(W):
        if is_wall(x, y) and not (x == PART and y in DOORWAY):
            solid[y][x] = True
for y in range(H):
    for x in range(W):
        if solid[y][x]:
            m = 0
            def open_at(xx, yy):
                return 0 <= xx < W and 0 <= yy < H and not solid[yy][xx]
            def floor_at(xx, yy):
                return 0 <= xx < W and 3 <= yy < H and not solid[yy][xx]
            m |= 1 if open_at(x - 1, y) else 0
            m |= 2 if open_at(x + 1, y) else 0
            m |= 4 if floor_at(x, y - 1) else 0
            m |= 8 if floor_at(x, y + 1) else 0
            grid[y][x] = f"walltop_{m}"
            continue
        corr = x > PART
        fam = "corr" if corr else "room"
        if y < 3:
            v = int(rng.choice([0] * 7 + [1, 2]))
            grid[y][x] = f"{fam}_wall_{['top', 'mid', 'bot'][y]}_{v}"
        elif x == PART:
            grid[y][x] = "threshold"
        elif y == 3:
            grid[y][x] = f"{fam}_floor_shadow_{int(rng.choice([0, 0, 1]))}"
        else:
            pool = [0, 0, 1, 1, 2, 2, 3] if fam == "room" else [0] * 8 + [2, 3]
            grid[y][x] = f"{fam}_floor_{int(rng.choice(pool))}"

# decals / props (top-left cell holds the multi-tile prop)
for c in range(3):
    grid[c][7] = f"room_wall_{['top', 'mid', 'bot'][c]}_3"
    grid[c][17] = f"corr_wall_{['top', 'mid', 'bot'][c]}_3"
props = [("room_window", 2, 0), ("corr_door_904", 13, 0), ("corr_door_905", 18, 0)]
for name, px, py in props:
    for yy in range(3):
        for xx in range(2):
            grid[py + yy][px + xx] = None
    grid[py][px] = name

(TS / "dorm_test_layout.json").write_text(json.dumps({"width": W, "height": H, "cells": grid}))

# ---------------------------------------------------------- 9. preview
prev = np.zeros((H * T, W * T, 3))
for y in range(H):
    for x in range(W):
        name = grid[y][x]
        if not name:
            continue
        c, r = tiles[name]["atlas"]
        sw, sh = tiles[name]["size"]
        prev[y * T:(y + sh) * T, x * T:(x + sw) * T] = atlas[r * T:(r + sh) * T, c * T:(c + sw) * T, :3]
img = Image.fromarray(prev.astype(np.uint8)).convert("RGBA")
hero = Image.open(ROOT / "assets/characters/hero_allegro_sheet.png").convert("RGBA").crop((0, 0, 48, 48))
img.alpha_composite(hero, (6 * T - 24, 5 * T - 30))
img.alpha_composite(hero.transpose(Image.FLIP_LEFT_RIGHT), (16 * T - 24, 6 * T - 30))
out_dir = Path("/home/allegro/.gemini/antigravity/brain/7bd8464a-a6fb-4d91-a857-5dcd24badf98")
img.convert("RGB").resize((W * T * 2, H * T * 2), Image.NEAREST).save(out_dir / "dorm_a_preview.png")
Image.fromarray(atlas, "RGBA").resize((COLS * T * 3, ROWS * T * 3), Image.NEAREST).save(out_dir / "dorm_a_atlas_x3.png")
print("door bbox", (dy0, dy1, dx0, dx1), "window bbox", (wy0, wy1, wx0, wx1))
print("tiles:", len(tiles))
