#!/usr/bin/env python3
"""Modular winter village-house tileset (Variant 2: dusty sage diamond + walnut wainscot).

Builds:
  - assets/tilesets/house_atlas.png (32x32 grid, 8x10 tiles)
  - assets/tilesets/house_tiles.json (tile name -> atlas coords/size)
  - assets/tilesets/house_test_layout.json (demo composer room + winter house hallway)
  - assets/tilesets/hallway_runner_rug.png (woven village runner rug for the hallway)
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
rng = np.random.default_rng(2026)


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


def clamp(a):
    return np.clip(a, 0, 255)


# Extract clean cornice, window & door geometry from original canvas
rows = list(range(12, 104))
for dup in (75, 60, 45, 30):
    rows.insert(rows.index(dup), dup)
band = src[rows]  # (96, 344, 3)
row_ref = np.median(band[:, 150:200], axis=1)


def object_bbox(x0, x1, y0=6, y1=96, thr=30, frac=0.75):
    diff = np.abs(band[y0:y1, x0:x1] - row_ref[y0:y1, None]).mean(2)
    m = diff > thr
    cols = np.where(m.mean(0) >= frac)[0]
    cx0, cx1 = cols.min(), cols.max() + 1
    rws = np.where(m[:, cx0:cx1].mean(1) >= frac)[0]
    return y0 + rws.min(), y0 + rws.max() + 1, x0 + cx0, x0 + cx1


# ------------------------------------------------- 1. Room wall (64 px tall = 2 tiles)
# Painterly dusty sage-slate wallpaper with subtle aged plaster mottling, faint seams & walnut trim
def build_sage_room_wall():
    out = np.zeros((64, T, 3), float)
    paper_nz = periodic_noise(64, T, 101, 4, 0.7) - 0.5
    mottle_nz = periodic_noise(64, T, 139, 3, 1.2) - 0.5
    fine_nz = periodic_noise(64, T, 107, 6) - 0.5
    base_sage = np.array([88.0, 98.0, 99.0])

    for y in range(64):
        if y == 0:
            out[y] = OUTLINE
        elif y < 5:
            shade = [78, 56, 42] if y == 1 else ([62, 44, 34] if y < 4 else [40, 29, 23])
            out[y] = np.array(shade) + fine_nz[y, :, None] * 2.5
        elif y == 5:
            out[y] = OUTLINE + 4
        elif y < 57:
            t = (y - 6) / 50.0
            vshade = 7.0 * (1.0 - t) - 7.5 * (t ** 1.35)
            under_cornice = -12.0 * max(0.0, 1.0 - (y - 6) / 5.0)
            above_base = -8.5 * max(0.0, 1.0 - (56 - y) / 4.0)
            for x in range(T):
                # Very delicate vintage wallpaper vertical stripe & faint 16px seam patina
                stripe = 1.6 if (x % 8 in (2, 3)) else (-1.2 if (x % 8 == 0) else 0.0)
                seam = -3.2 if (x == 16) else (1.2 if x == 17 else 0.0)
                warm_shift = np.array([mottle_nz[y, x] * 6.0, mottle_nz[y, x] * 4.5, mottle_nz[y, x] * 2.0])
                out[y, x] = (
                    base_sage
                    + vshade
                    + under_cornice
                    + above_base
                    + stripe
                    + seam
                    + warm_shift
                    + paper_nz[y, x] * 5.2
                    + fine_nz[y, x] * 2.4
                )
        elif y == 57:
            out[y] = OUTLINE + 5
        elif y == 58:
            out[y] = np.array([88, 63, 46]) + fine_nz[y, :, None] * 2.0
        elif y < 63:
            out[y] = np.array([58, 42, 32]) + fine_nz[y, :, None] * 2.5
        else:
            out[y] = OUTLINE

    return clamp(out)


# ------------------------------------------------- 2. Hallway wall (64 px tall = 2 tiles)
# Warm linen plaster top + walnut chair rail + waist-height walnut vertical wainscot
def build_house_hall_wall():
    out = np.zeros((64, T, 3), float)
    plaster_nz = periodic_noise(64, T, 203, 5, 0.8) - 0.5
    wood_nz = periodic_noise(64, T, 211, 6, 4.0) - 0.5
    fine_nz = periodic_noise(64, T, 223, 6) - 0.5

    for y in range(64):
        if y == 0:
            out[y] = OUTLINE
        elif y < 5:
            shade = [76, 54, 40] if y == 1 else ([62, 43, 32] if y < 4 else [42, 30, 23])
            out[y] = np.array(shade) + fine_nz[y, :, None] * 3
        elif y == 5:
            out[y] = OUTLINE + 4
        elif y < 33:
            t = (y - 6) / 26.0
            vshade = 6.0 * (1.0 - t) - 5.0 * (t ** 1.5)
            under = -10.0 * max(0.0, 1.0 - (y - 6) / 4.0)
            out[y] = np.array([144.0, 136.0, 120.0]) + vshade + under + plaster_nz[y, :, None] * 7.0 + fine_nz[y, :, None] * 3.0
        elif y == 33:
            out[y] = OUTLINE + 6
        elif y == 34:
            out[y] = [104, 76, 54]   # Chair rail highlight
        elif y == 35:
            out[y] = [74, 52, 38]
        elif y == 36:
            out[y] = [40, 28, 21]    # Under-rail shadow
        elif y < 57:
            # Walnut vertical clapboard/wainscot (4 planks per 32px tile -> 8px each, waist-high 28px from floor)
            base_w = np.array([76.0, 54.0, 39.0])
            top_sh = -8.0 * max(0.0, 1.0 - (y - 37) / 4.0)
            for x in range(T):
                px = x % 8
                plank_tone = ((x // 8) % 2) * 3.0 - 1.5
                if px == 0:
                    c = np.array([38.0, 27.0, 21.0])
                elif px == 1:
                    c = base_w + np.array([9.0, 7.0, 5.0]) + plank_tone
                elif px == 7:
                    c = base_w - np.array([7.0, 5.0, 4.0]) + plank_tone
                else:
                    c = base_w + plank_tone
                out[y, x] = c + top_sh + wood_nz[y, x] * 8.0 + fine_nz[y, x] * 3.0
        elif y == 57:
            out[y] = OUTLINE + 4
        elif y == 58:
            out[y] = np.array([86, 61, 44])
        elif y < 63:
            out[y] = np.array([58, 41, 30]) + fine_nz[y, :, None] * 3
        else:
            out[y] = OUTLINE
    return clamp(out)


room_wall_base = build_sage_room_wall()
hall_wall_base = build_house_hall_wall()


# ------------------------------------------------- 3. Clean residential decals
def score_sheet(img, y0, x0, w=12, h=15):
    img[y0 + 1:y0 + h + 1, x0 + 1:x0 + w + 1] *= 0.72
    paper = np.array([186, 174, 148])
    img[y0:y0 + h, x0:x0 + w] = paper
    img[y0:y0 + h, x0 + w - 1] = paper * 0.86
    for sy in range(y0 + 3, y0 + h - 2, 2):
        if (sy - y0) % 6 != 1:
            img[sy, x0 + 2:x0 + w - 2] = [104, 90, 76]
    for nx, ny in ((x0 + 4, y0 + 4), (x0 + 7, y0 + 6), (x0 + 5, y0 + 10)):
        img[ny, nx] = [40, 32, 28]
    img[y0 + 1, x0 + w // 2] = [155, 42, 36]
    return img


def light_switch(img, y0, x0):
    img[y0 + 1:y0 + 8, x0 + 1:x0 + 7] *= 0.78
    img[y0:y0 + 7, x0:x0 + 6] = [176, 166, 146]
    img[y0 + 6, x0:x0 + 6] = [110, 102, 88]
    img[y0:y0 + 7, x0 + 5] = [122, 114, 98]
    img[y0 + 2:y0 + 5, x0 + 2:x0 + 4] = [148, 138, 120]
    img[y0 + 3, x0 + 2:x0 + 4] = [196, 186, 166]
    return img


def socket(img, y0, x0):
    img[y0:y0 + 7, x0:x0 + 7] = [170, 162, 144]
    img[y0 + 6, x0:x0 + 7] = [102, 95, 84]
    img[y0:y0 + 7, x0 + 6] = [116, 108, 96]
    img[y0 + 3, x0 + 2] = img[y0 + 3, x0 + 4] = [42, 36, 32]
    return img


def radiator(img, y0, x0, w=26, h=18):
    iron = np.array([124, 120, 108])
    img[y0 + h, x0 + 1:x0 + w + 1] *= 0.62
    for i in range(0, w, 3):
        if x0 + i + 2 < x0 + w:
            img[y0:y0 + h, x0 + i] = iron * 1.12
            img[y0:y0 + h, x0 + i + 1] = iron
            img[y0:y0 + h, x0 + i + 2] = iron * 0.62
        else:
            img[y0:y0 + h, x0 + i:x0 + w] = iron * 0.9
    img[y0, x0:x0 + w] = iron * 1.24
    img[y0 + 2, x0:x0 + w] = iron * 0.82
    img[y0 + h - 3, x0:x0 + w] = iron * 0.82
    img[y0 - 1, x0:x0 + w] = OUTLINE + 10
    img[y0 + 4:y0 + 7, max(0, x0 - 3):x0] = [92, 88, 80]
    return img


def winter_painting(img, y0=12, x0=5, w=22, h=20):
    """Walnut-framed small winter village painting on the hallway plaster."""
    # Drop shadow
    img[y0 + 2:y0 + h + 2, x0 + 2:x0 + w + 2] *= 0.72
    # Outer walnut frame
    img[y0:y0 + h, x0:x0 + w] = OUTLINE + 6
    img[y0 + 1:y0 + h - 1, x0 + 1:x0 + w - 1] = [84, 58, 40]
    img[y0 + 2:y0 + h - 2, x0 + 2:x0 + w - 2] = [148, 128, 96]  # inner passe-partout
    # Canvas (16x14)
    cy0, cx0, cw, ch = y0 + 3, x0 + 3, w - 6, h - 6
    for yy in range(ch):
        t = yy / max(1, ch - 1)
        sky = np.array([34, 48, 76]) * (1 - t) + np.array([62, 82, 112]) * t
        img[cy0 + yy, cx0:cx0 + cw] = sky
    # Moon
    img[cy0 + 2:cy0 + 4, cx0 + 2:cx0 + 4] = [212, 220, 232]
    # Snowy horizon
    img[cy0 + ch - 4:cy0 + ch, cx0:cx0 + cw] = [176, 186, 200]
    img[cy0 + ch - 3:cy0 + ch, cx0:cx0 + cw] = [152, 164, 182]
    # Pine tree silhouettes with snow dots
    for px, ph in ((cx0 + 4, 7), (cx0 + 12, 6)):
        for row in range(ph):
            span = row // 2
            img[cy0 + ch - 4 - ph + row, px - span:px + span + 1] = [26, 38, 36]
            if row % 2 == 1 and span > 0:
                img[cy0 + ch - 4 - ph + row, px - span + 1] = [190, 204, 218]
    # Tiny warm lit cottage window
    img[cy0 + ch - 7:cy0 + ch - 4, cx0 + 7:cx0 + 11] = [44, 34, 28]
    img[cy0 + ch - 6, cx0 + 8] = [232, 178, 86]
    return img


def wall_variants(base, kind):
    v = [base.copy() for _ in range(4)]
    if kind == "room":
        v[1][6:57] = clamp(v[1][6:57] * np.array([0.985, 0.99, 0.99]))
        socket(v[2], 46, 13)
        light_switch(v[3], 32, 13)
    else:
        # Hallway:
        # v[1]: light switch above walnut wainscot
        light_switch(v[1], 22, 13)
        # v[2]: cast-iron radiator on walnut wainscot
        radiator(v[2], 41, 3, 26, 14)
        # v[3]: winter cottage painting on plaster + radiator below
        winter_painting(v[3], 9, 6, 20, 18)
        radiator(v[3], 41, 3, 26, 14)
    return [clamp(x) for x in v]


room_walls = wall_variants(room_wall_base, "room")
hall_walls = wall_variants(hall_wall_base, "corr")

# ----------------------------------------------------------------- 4. Floors
# Room floor: warm dark walnut planks (no circular spots)
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
for p in range(4):
    y = p * 8
    room_floor_base[y] = room_floor_base[y] * 0.58
    room_floor_base[y + 1] = room_floor_base[y + 1] * 1.05
room_floor_base = clamp(room_floor_base)
JOINTS = ((3, 21, 12, 28), (10, 26, 5, 19), (17, 2, 24, 9), (25, 13, 29, 6))


def add_joints(tile, xs):
    for p, jx in enumerate(xs):
        y = p * 8
        tile[y + 1:y + 8, jx] *= 0.68
        tile[y + 1:y + 8, jx + 1] *= 1.04
    return tile


def floor_room_variants(base):
    v = [add_joints(base.copy(), JOINTS[i]) for i in range(4)]
    v[1][9:16, 22:31] = v[1][9:16, 22:31] * np.array([0.89, 0.85, 0.83])
    v[1][19, 7:9] = v[1][19, 7:9] * 0.74
    v[1][20, 8] = v[1][20, 8] * 0.82
    for i in range(10):
        v[2][20 + i // 4, 6 + i] *= 1.07
        v[2][4 + i // 5, 16 + i] *= 1.06
    v[3][17:24, 3:18] = v[3][17:24, 3:18] * np.array([0.91, 0.88, 0.86])
    v[3][12:15, 11:25] = v[3][12:15, 11:25] * np.array([0.93, 0.91, 0.89])
    return [clamp(x) for x in v]


room_floors = floor_room_variants(room_floor_base)

# Hallway floor: warm honey-aged oak village house boards (distinct from room walnut, cohesive wood)
hall_floor_base = match_mean(room_floor_base, [92, 68, 50])
hall_nz = periodic_noise(T, T, 83, 6, 3.0) - 0.5
hall_floor_base += hall_nz[..., None] * 5
for p in range(4):
    y = p * 8
    hall_floor_base[y] = hall_floor_base[y] * 0.60
    hall_floor_base[y + 1] = hall_floor_base[y + 1] * 1.06
hall_floor_base = clamp(hall_floor_base)
JOINTS_H = ((7, 25, 14, 3), (15, 4, 21, 28), (22, 11, 29, 17), (1, 18, 8, 24))


def floor_hall_variants(base):
    v = [add_joints(base.copy(), JOINTS_H[i]) for i in range(4)]
    v[1][1:8, 12:24] *= np.array([0.92, 0.90, 0.88])
    v[2][17:24, 4:14] *= np.array([1.06, 1.05, 1.04])
    v[3][25:32, 18:29] *= np.array([0.90, 0.88, 0.86])
    return [clamp(x) for x in v]


hall_floors = floor_hall_variants(hall_floor_base)


def with_wall_shadow(tile, depth=7):
    t = tile.copy()
    for y in range(depth):
        t[y] *= 0.52 + 0.48 * (y / depth) ** 0.8
    return clamp(t)


threshold = np.concatenate([room_floors[0][:, :16], hall_floors[0][:, 16:]], axis=1)
threshold[:, 15] = clamp(threshold[:, 15] * 0.78)
threshold[:, 16] = clamp(threshold[:, 16] * 1.04)

# ---------------------------------------------------- 5. Wall-top cutaway (16 masks)
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
    if mask & 8:
        t[24] = mid * 0.9
        t[25:28] = light
        t[28:31] = np.array([70, 49, 35])
        t[31] = OUTLINE
    return clamp(t)


walltops = [walltop(m) for m in range(16)]
void = np.zeros((T, T, 3)) + np.array([14, 11, 11])

# ---------------------------------------------------- 6. 2x2 Props (doors, winter window, coat rack)
dy0, dy1, dx0, dx1 = object_bbox(244, 306)
dy1 = 96
wy0, wy1, wx0, wx1 = object_bbox(36, 108)
door_src = np.clip(band[dy0:dy1, dx0:dx1], 0, 255).astype(np.uint8)
door = np.asarray(Image.fromarray(door_src).resize((36, 54), Image.Resampling.LANCZOS), dtype=float)
dh, dw = door.shape[:2]
door[0, :] = OUTLINE
door[:, 0] = OUTLINE
door[:, dw - 1] = OUTLINE
# Crisp flush low sill and continuous vertical jambs down to floor
door[dh - 4, 5:dw - 5] = [26, 18, 14]
door[dh - 3, 5:dw - 5] = [60, 43, 30]
door[dh - 2, 5:dw - 5] = [44, 31, 22]
door[dh - 1, :] = OUTLINE

win_src = np.clip(band[wy0:wy1, wx0:wx1], 0, 255).astype(np.uint8)
window_frame = np.asarray(Image.fromarray(win_src).resize((44, 44), Image.Resampling.LANCZOS), dtype=float)
gh, gw = window_frame.shape[:2]
window_frame[0, :] = OUTLINE
window_frame[gh - 1, :] = OUTLINE
window_frame[:, 0] = OUTLINE
window_frame[:, gw - 1] = OUTLINE

# Painterly overcast winter morning sky, misty distant treeline, natural snow-laden pines & frost sheen
glass_mask = (window_frame[..., 0] < 72) & (window_frame[..., 2] > window_frame[..., 0] + 3)
sky_nz = periodic_noise(gh, gw, 509, 4) - 0.5
for y in range(gh):
    for x in range(gw):
        if glass_mask[y, x]:
            ty = y / max(1, gh - 1)
            # Soft wintry dusk-morning gradient (muted slate-blue zenith -> misty pale horizon)
            sky = np.array([104.0, 126.0, 156.0]) * (1 - ty) + np.array([174.0, 190.0, 210.0]) * ty
            sky += sky_nz[y, x] * 10.0
            window_frame[y, x] = sky

# Misty distant forest treeline along the horizon (adds atmospheric depth!)
for x in range(gw):
    ridge_h = int(10 + 3 * np.sin(x * 0.28) + 1.8 * np.cos(x * 0.7))
    for y in range(max(0, gh - ridge_h - 5), gh - 5):
        if glass_mask[y, x]:
            depth_t = (y - (gh - ridge_h - 5)) / max(1.0, float(ridge_h))
            mist_col = np.array([96.0, 112.0, 134.0]) * (1.0 - 0.25 * depth_t) + sky_nz[y, x] * 6.0
            window_frame[y, x] = mist_col

# Painterly layered winter spruce silhouettes (irregular snow-dusted boughs, no harsh zebra stripes)
pine_rng = np.random.default_rng(42)
def draw_glass_pine(cx, base_y, h_tree, dark_col, mid_col):
    for row in range(h_tree):
        yy = base_y - h_tree + row
        t = row / max(1.0, float(h_tree - 1))
        # Natural jagged bough tiers widening downward
        tier_wave = 1.2 * np.sin(row * 1.45)
        half_w = max(0, int(0.7 + t * (h_tree * 0.36) + tier_wave * (0.4 + 0.6 * t)))
        for xx in range(cx - half_w, cx + half_w + 1):
            if 0 <= yy < gh and 0 <= xx < gw and glass_mask[yy, xx]:
                dx = xx - cx
                edge_ratio = abs(dx) / max(1.0, float(half_w))
                bough_top = ((row + (1 if dx > 0 else 0)) % 4 == 0)
                if bough_top and edge_ratio < 0.85 and (pine_rng.random() < 0.72 or abs(dx) <= 1):
                    col = np.array([188.0, 202.0, 218.0]) if dx <= 0 else np.array([162.0, 178.0, 198.0])
                else:
                    col = mid_col if dx < 0 else dark_col
                    col = col + sky_nz[yy, xx] * 10.0
                window_frame[yy, xx] = col

draw_glass_pine(int(gw * 0.25), gh - 6, 14, np.array([38.0, 52.0, 62.0]), np.array([54.0, 70.0, 82.0]))
draw_glass_pine(int(gw * 0.75), gh - 6, 18, np.array([34.0, 48.0, 58.0]), np.array([50.0, 66.0, 78.0]))

# Soft contoured snowbank at bottom of glass panes
for y in range(gh - 10, gh):
    for x in range(gw):
        if glass_mask[y, x]:
            drift = int(1.4 * np.sin(x * 0.24 + 0.5))
            if y >= gh - 7 + drift:
                depth = (y - (gh - 7 + drift)) / 4.0
                snow = np.array([208.0, 218.0, 232.0]) * (1.0 - 0.14 * min(1.0, depth))
                window_frame[y, x] = snow + sky_nz[y, x] * 6.0

# Delicate frosted pane corners + subtle diagonal glass reflection sheen
for y in range(gh):
    for x in range(gw):
        if glass_mask[y, x]:
            diag = (x * 0.7 + y)
            if 14 <= diag <= 16 or 29 <= diag <= 31:
                window_frame[y, x] = window_frame[y, x] * 0.86 + np.array([225.0, 236.0, 248.0]) * 0.14
            near_frame = False
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < gh and 0 <= nx < gw and not glass_mask[ny, nx]:
                    near_frame = True
                    break
            if near_frame:
                window_frame[y, x] = window_frame[y, x] * 0.82 + np.array([210.0, 224.0, 240.0]) * 0.18

# Soft distant snowflakes in glass (varied subtle brightness)
sf_rng = np.random.default_rng(77)
for i in range(18):
    sy = int(sf_rng.integers(4, gh - 7))
    sx = int(sf_rng.integers(4, gw - 4))
    if glass_mask[sy, sx]:
        mix = 0.45 if i % 2 == 0 else 0.72
        window_frame[sy, sx] = window_frame[sy, sx] * (1.0 - mix) + np.array([232.0, 240.0, 250.0]) * mix


def prop(bg_tile, obj, oy, center=32):
    img = np.concatenate([bg_tile, bg_tile], axis=1).copy()
    ow = obj.shape[1]
    ox = max(0, center - ow // 2)
    ow = min(ow, 64 - ox)
    img[oy:oy + obj.shape[0], ox:ox + ow] = obj[:, :ow]
    return img, ox, ow


def add_coat_rack(bg_tile):
    """2x2 wall coat rack with hanging winter parka & scarf + boot mat for village hallway."""
    img = np.concatenate([bg_tile, bg_tile], axis=1).copy()
    # Top walnut peg bar at y=14..19, x=14..50
    img[13, 14:50] = OUTLINE
    img[14:19, 14:50] = [74, 52, 37]
    img[14, 15:49] = [96, 68, 49]
    img[19, 14:50] = OUTLINE
    # 3 brass pegs
    for px in (20, 32, 44):
        img[16:18, px:px + 2] = [186, 154, 92]

    # Left: hanging dark wool winter coat (x=15..28, y=18..46)
    img[17:47, 15:29] *= 0.86
    for y in range(18, 46):
        w_half = 4 if y < 23 else (6 if y < 39 else 7)
        cx = 21
        for x in range(cx - w_half, cx + w_half + 1):
            if x == cx - w_half or x == cx + w_half or y == 45:
                img[y, x] = OUTLINE
            else:
                fold = -6 if (x - cx) in (-2, 2) else (5 if x < cx else -2)
                img[y, x] = np.clip(np.array([56, 64, 62]) + fold, 0, 255)
    # Coat collar
    img[18:22, 18:25] = [42, 48, 46]

    # Middle: hanging burgundy-wool scarf (x=29..36, y=18..43)
    for y in range(18, 41):
        img[y, 30:35] = [116, 46, 46]
        img[y, 30] = OUTLINE
        img[y, 35] = OUTLINE
        if y % 4 == 0:
            img[y, 31:35] = [94, 36, 36]
    for fx in (31, 33):
        img[41:44, fx] = [148, 128, 108]

    # Right: knitted cap / bag strap on 3rd peg (x=41..47, y=17..25)
    img[17:25, 41:48] = [88, 72, 54]
    img[17, 41:48] = OUTLINE
    img[25, 41:48] = OUTLINE
    img[17:26, 41] = OUTLINE
    img[17:26, 47] = OUTLINE

    # Small dark boot mat / wooden shoe shelf at baseboard (x=17..47, y=51..58)
    img[51, 17:47] = OUTLINE
    img[52:58, 17:47] = [66, 48, 35]
    img[52, 18:46] = [88, 64, 46]
    img[58, 17:47] = OUTLINE
    # Pair of dark winter boots on shelf
    for bx in (23, 35):
        img[48:53, bx:bx + 5] = [38, 32, 30]
        img[52, bx:bx + 6] = [26, 21, 20]
    return clamp(img)


def build_hall_passage():
    """Walkable 2x2 open interior doorway passage between hallway and side rooms."""
    img = np.zeros((64, 64, 3), float)
    floor_strip = np.concatenate([hall_floors[0], hall_floors[1]], axis=1)
    wall_strip = np.concatenate([hall_walls[0], hall_walls[1]], axis=1)
    img[:64, :] = wall_strip
    # Open oak floor strip through full 64px doorway height (flows seamlessly from passage_cap)
    for y in range(64):
        img[y, 12:52] = floor_strip[y % T, 12:52]
    # Left & right wooden door jambs (x=7..11 and x=52..56) spanning full height
    for x0 in (7, 52):
        img[:, x0:x0 + 5] = [78, 54, 38]
        img[:, x0 + 1] = [104, 74, 52]
        img[:, x0] = OUTLINE
        img[:, x0 + 4] = OUTLINE
    return clamp(img)


def build_passage_cap():
    """Walkable 2x1 wall-cutaway cap + horizontal threshold linking upper bedrooms to hall_passage."""
    img = np.zeros((32, 64, 3), float)
    wall_strip = np.concatenate([walltop(8), walltop(8)], axis=1)
    img[:, :] = wall_strip
    # Top edge of walltop also touches bedroom floor above -> add top bevel
    img[0, :] = OUTLINE
    img[1:3, :] = [92, 64, 46]
    img[3, :] = [60, 42, 31]

    r_strip = np.concatenate([room_floors[0], room_floors[1]], axis=1)
    h_strip = np.concatenate([hall_floors[0], hall_floors[1]], axis=1)
    # Seamless floor transition between walnut room planks and warm oak hallway planks
    for y in range(16):
        img[y, 12:52] = r_strip[y, 12:52]
    for y in range(16, 32):
        img[y, 12:52] = h_strip[y, 12:52]
    img[16, 12:52] *= 0.68
    img[17, 12:52] *= 1.04

    # Door jamb cutaways lining up seamlessly with walltop outer sides (x=0..6, 57..63) and hall_passage below
    for x0 in (7, 52):
        img[:, x0:x0 + 5] = [78, 54, 38]
        img[:, x0 + 1] = [104, 74, 52]
        img[0, x0:x0 + 5] = OUTLINE
        img[:, x0] = OUTLINE
        img[:, x0 + 4] = OUTLINE
    return clamp(img)


def build_passage_cap_fg(cap_rgb):
    """Foreground RGBA overlay for passage_cap: keeps side walltops & jambs opaque, doorway floor transparent."""
    fg = np.zeros((32, 64, 4), np.uint8)
    rgb = np.clip(cap_rgb, 0, 255).astype(np.uint8)
    fg[:, :12, :3] = rgb[:, :12]
    fg[:, :12, 3] = 255
    fg[:, 52:, :3] = rgb[:, 52:]
    fg[:, 52:, 3] = 255
    return fg


def build_hall_wall_end(side: str):
    """64x32 hallway wall with finished vertical walnut casing trim on 'left' or 'right' exposed partition end."""
    img = hall_wall_base.copy()
    if side == "right":
        img[:, 28] = OUTLINE
        img[:, 29] = [104, 74, 52]
        img[:, 30] = [78, 54, 38]
        img[:, 31] = OUTLINE
    else:
        img[:, 0] = OUTLINE
        img[:, 1] = [104, 74, 52]
        img[:, 2] = [78, 54, 38]
        img[:, 3] = OUTLINE
    return clamp(img)


hall_door_plain, _, _ = prop(hall_walls[0], door, 10)
hall_coatrack = add_coat_rack(hall_walls[0])
hall_passage = build_hall_passage()
passage_cap = build_passage_cap()
passage_cap_fg = build_passage_cap_fg(passage_cap)
hall_wall_end_r = build_hall_wall_end("right")
hall_wall_end_l = build_hall_wall_end("left")
room_door, _, _ = prop(room_walls[0], door, 10)
room_window, _, _ = prop(room_walls[0], window_frame, 10)

for p in (hall_door_plain, hall_coatrack, hall_passage, passage_cap, room_door, room_window):
    np.clip(p, 0, 255, out=p)

# ---------------------------------------------------------- 7. Compact 2-tile Atlas assembly (8x10)
COLS, ROWS = 8, 10
atlas = np.zeros((ROWS * T, COLS * T, 4), np.uint8)
tiles = {}


def put(name, img, col, row, size=(1, 1)):
    h, w = img.shape[:2]
    if img.shape[2] == 4:
        atlas[row * T:row * T + h, col * T:col * T + w] = np.clip(img, 0, 255).astype(np.uint8)
    else:
        atlas[row * T:row * T + h, col * T:col * T + w, :3] = np.clip(img, 0, 255).astype(np.uint8)
        atlas[row * T:row * T + h, col * T:col * T + w, 3] = 255
    tiles[name] = {"atlas": [col, row], "size": list(size)}


for v in range(4):
    for part, (y0, row) in enumerate(((0, 0), (32, 1))):
        pname = ["top", "bot"][part]
        put(f"room_wall_{pname}_{v}", room_walls[v][y0:y0 + 32], v, row)
        put(f"hall_wall_{pname}_{v}", hall_walls[v][y0:y0 + 32], 4 + v, row)
    put(f"room_floor_{v}", room_floors[v], v, 2)
    put(f"hall_floor_{v}", hall_floors[v], 4 + v, 2)

put("room_floor_shadow_0", with_wall_shadow(room_floors[0]), 0, 3)
put("room_floor_shadow_1", with_wall_shadow(room_floors[1]), 1, 3)
put("hall_floor_shadow_0", with_wall_shadow(hall_floors[0]), 2, 3)
put("hall_floor_shadow_1", with_wall_shadow(hall_floors[1]), 3, 3)
put("threshold", threshold, 4, 3)
put("void", void, 5, 3)

for m in range(16):
    put(f"walltop_{m}", walltops[m], m % 8, 4 + m // 8)

put("hall_door", hall_door_plain, 0, 6, (2, 2))
put("hall_coatrack", hall_coatrack, 2, 6, (2, 2))
put("room_window", room_window, 4, 6, (2, 2))
put("room_door", room_door, 6, 6, (2, 2))
put("hall_passage", hall_passage, 0, 8, (2, 2))
put("passage_cap", passage_cap, 2, 8, (2, 1))
put("passage_cap_fg", passage_cap_fg, 4, 8, (2, 1))
for part, pname in enumerate(("top", "bot")):
    put(f"hall_wall_end_r_{pname}", hall_wall_end_r[part * 32:(part + 1) * 32], 6, 8 + part)
    put(f"hall_wall_end_l_{pname}", hall_wall_end_l[part * 32:(part + 1) * 32], 7, 8 + part)

Image.fromarray(atlas, "RGBA").save(TS / "house_atlas.png")
(TS / "house_tiles.json").write_text(json.dumps({"tile_size": T, "tiles": tiles}, indent=1))

# ---------------------------------------------------------- 8. Woven hallway runner rug sprite
RW, RH = 192, 46
rug = np.zeros((RH, RW, 4), np.uint8)
rug_nz = periodic_noise(RH, RW, 313, 6) - 0.5
wear_nz = periodic_noise(RH, RW, 359, 3, 0.5) - 0.5
for y in range(RH):
    for x in range(RW):
        if x < 4 or x >= RW - 4:
            # Soft cotton tassel fringe every 2px with natural slight length variation
            if y % 2 == 0 and 3 <= y < RH - 3:
                tip = (x == 0 or x == RW - 1)
                if not tip or (y % 4 == 0):
                    shade = 0.86 if tip else 1.0
                    rug[y, x] = [int(176 * shade), int(158 * shade), int(128 * shade), 235]
            continue
        bx = x - 4
        bw = RW - 8  # 184px wide
        if y in (0, RH - 1) or bx in (0, bw - 1):
            rug[y, x] = [22, 15, 15, 255]
        elif y < 5 or y >= RH - 5 or bx < 6 or bx >= bw - 6:
            # Deep burgundy frame with woven antique-ochre double stripe
            weave = ((x + y) % 2) * 4 - 2
            if y in (2, RH - 3) and 2 <= bx < bw - 2:
                c = np.array([154.0, 126.0, 84.0]) + weave + rug_nz[y, x] * 10
            elif bx in (2, bw - 3) and 2 <= y < RH - 2:
                c = np.array([148.0, 120.0, 80.0]) + weave + rug_nz[y, x] * 10
            elif y in (4, RH - 5) and 4 <= bx < bw - 4:
                c = np.array([78.0, 32.0, 30.0]) + weave
            else:
                c = np.array([106.0, 44.0, 40.0]) + weave + rug_nz[y, x] * 10
            rug[y, x, :3] = np.clip(c, 0, 255)
            rug[y, x, 3] = 255
        else:
            weave = ((x + y) % 2) * 5 - 2
            # Subtle foot-traffic wear patina down the middle of the runner
            center_dist = abs(y - RH * 0.5) / (RH * 0.5)
            wear = (1.0 - center_dist) * (wear_nz[y, x] * 14.0 - 4.0)
            base = np.array([118.0, 44.0, 42.0]) + weave + rug_nz[y, x] * 13.0 + wear
            # Symmetrical centered woven diamond medallions (11 motifs spaced 16px apart, centered cleanly!)
            rel_x = bx - bw * 0.5
            cy = RH * 0.5 - 0.5
            dy = abs(y - cy)
            # Distance to nearest medallion center (period 16px, bounded well inside border)
            if abs(rel_x) <= 84:
                dx = abs(((rel_x + 8.0) % 16.0) - 8.0)
                manh = dx + dy * 1.15
                if manh <= 5.2 and manh >= 3.3:
                    base += np.array([34.0, 24.0, 12.0])  # ochre diamond outline
                elif manh < 3.3:
                    base += np.array([-16.0, -8.0, -6.0])  # deep plum diamond center
                    if manh < 1.3:
                        base += np.array([46.0, 36.0, 20.0])  # tiny gold woven dot
            rug[y, x, :3] = np.clip(base, 0, 255)
            rug[y, x, 3] = 255

Image.fromarray(rug, "RGBA").save(TS / "hallway_runner_rug.png")

# ---------------------------------------------------------- 9. Village House layout (33x16, 2-tile walls)
# Left: Hero room (7x5 floor) -> Center: Hallway + solid partition (y=7) + Brother's & Parents' rooms above -> Right: Entry/Dining/Kitchen
W, H = 33, 16
grid = [[None] * W for _ in range(H)]
solid = [[False] * W for _ in range(H)]
inside = [[False] * W for _ in range(H)]

# 1) Mark walkable/walled interior regions (top walltop at y=0, upper-room/hall partition walltop at y=7)
for y in range(8, 15):
    for x in range(1, 8):
        inside[y][x] = True  # Hero room (wall y=8..9, floor y=10..14, bottom walltop y=15)
for y in range(1, 7):
    for x in range(9, 16):
        inside[y][x] = True  # Brother room (wall y=1..2, floor y=3..6)
    for x in range(17, 24):
        inside[y][x] = True  # Parents room (wall y=1..2, floor y=3..6)
for y in range(8, 13):
    for x in range(9, 24):
        inside[y][x] = True  # Central hallway (wall y=8..9, floor y=10..12, bottom walltop y=13)
for y in range(1, 15):
    for x in range(25, 32):
        inside[y][x] = True  # Entry (y=1..6) + Dining/Kitchen (y=8..14), bottom walltop y=15

# Doorway connections between regions (horizontal & vertical partition openings)
for yy in (11, 12):
    inside[yy][8] = True   # Hero room <-> Hallway
    inside[yy][24] = True  # Hallway <-> Entry/Kitchen
for xx in (11, 12, 19, 20):
    inside[7][xx] = True   # Upper room floors <-> Hallway passages across y=7 wall
for xx in (25, 26, 29, 30, 31):
    inside[7][xx] = False  # Small Entry <-> Dining wing partition walls (2-tile central passage x=27..28; 96px wall on right x=29..31)

# Outer boundary + interior partition walls become solid walltop cells
for y in range(H):
    for x in range(W):
        if inside[y][x]:
            continue
        adj = False
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                ny, nx = y + dy, x + dx
                if 0 <= ny < H and 0 <= nx < W and inside[ny][nx]:
                    adj = True
        if adj:
            solid[y][x] = True

# Build walltop tiles + interior floor/wall tiles
for y in range(H):
    for x in range(W):
        if solid[y][x]:
            m = 0
            def open_in(xx, yy):
                # Do not treat passage_cap cells at y=7 as horizontally open in walltop masks;
                # passage_cap renders its own continuous outer walltop + door jamb inset at x=7 / x=56.
                if yy == 7 and xx in (11, 12, 19, 20):
                    return False
                return 0 <= xx < W and 0 <= yy < H and inside[yy][xx]
            m |= 1 if open_in(x - 1, y) else 0
            m |= 2 if open_in(x + 1, y) else 0
            m |= 4 if open_in(x, y - 1) else 0
            m |= 8 if open_in(x, y + 1) else 0
            grid[y][x] = f"walltop_{m}"
            continue
        if not inside[y][x]:
            continue

        if x == 8 and y in (11, 12):
            grid[y][x] = "threshold"
            continue
        if x == 24 and y in (11, 12):
            grid[y][x] = "hall_floor_0"
            continue

        # Room family & wall row detection
        in_hero = (1 <= x <= 7 and 8 <= y <= 14)
        in_top_rooms = (9 <= x <= 23 and 1 <= y <= 6)
        in_hall = (9 <= x <= 23 and 8 <= y <= 12)
        in_entry_kitchen = (25 <= x <= 31 and 1 <= y <= 14)

        if in_hero:
            if y < 10:
                v = 1 if x in (1, 5) else 0
                grid[y][x] = f"room_wall_{['top', 'bot'][y - 8]}_{v}"
            elif y == 10:
                grid[y][x] = f"room_floor_shadow_{int(rng.choice([0, 0, 1]))}"
            else:
                grid[y][x] = f"room_floor_{int(rng.choice([0, 0, 1, 1, 2, 3]))}"
        elif in_top_rooms:
            if y < 3:
                v = 1 if x % 3 == 0 else 0
                grid[y][x] = f"room_wall_{['top', 'bot'][y - 1]}_{v}"
            elif y == 3:
                grid[y][x] = f"room_floor_shadow_{int(rng.choice([0, 0, 1]))}"
            else:
                grid[y][x] = f"room_floor_{int(rng.choice([0, 0, 1, 2, 3]))}"
        elif in_hall:
            if y < 10:
                v = 1 if x == 16 else 0
                grid[y][x] = f"hall_wall_{['top', 'bot'][y - 8]}_{v}"
            elif y == 10 and x not in (11, 12, 19, 20):
                grid[y][x] = f"hall_floor_shadow_{int(rng.choice([0, 0, 1]))}"
            else:
                grid[y][x] = f"hall_floor_{int(rng.choice([0, 0, 1, 1, 2, 3]))}"
        elif in_entry_kitchen:
            if y < 3:
                v = 1 if x == 26 else 0
                grid[y][x] = f"hall_wall_{['top', 'bot'][y - 1]}_{v}"
            elif y == 3 and x not in (27, 28):
                grid[y][x] = f"hall_floor_shadow_{int(rng.choice([0, 0, 1]))}"
            elif 8 <= y <= 9 and x in (25, 26, 29, 30, 31):
                pname = ["top", "bot"][y - 8]
                if x == 26:
                    grid[y][x] = f"hall_wall_end_r_{pname}"
                elif x == 29:
                    grid[y][x] = f"hall_wall_end_l_{pname}"
                else:
                    grid[y][x] = f"hall_wall_{pname}_0"
            elif y == 10 and x in (25, 26, 29, 30, 31):
                grid[y][x] = f"hall_floor_shadow_{int(rng.choice([0, 0, 1]))}"
            else:
                grid[y][x] = f"hall_floor_{int(rng.choice([0, 0, 1, 1, 2, 3]))}"

# Clean interior wall accents (no music notes on hero room walls; hallway painting/radiator temporarily removed)
for c in range(2):
    grid[8 + c][6] = f"room_wall_{['top', 'bot'][c]}_2"
    grid[8 + c][7] = f"room_wall_{['top', 'bot'][c]}_3"

# Multi-tile architectural props:
# 2x2: Hero window beside bed, 2 walkable doorways to brother/parents rooms, main entrance door + coatrack
# 2x1: walkable passage caps bridging the y=7 wall between bedrooms and hall_passage
props_2x2 = [
    ("room_window", 2, 8),
    ("hall_passage", 11, 8),
    ("hall_passage", 19, 8),
    ("hall_door", 27, 1),
    ("hall_coatrack", 29, 1),
]
for name, px, py in props_2x2:
    for yy in range(2):
        for xx in range(2):
            grid[py + yy][px + xx] = None
    grid[py][px] = name

for name, px, py in (("passage_cap", 11, 7), ("passage_cap", 19, 7)):
    grid[py][px] = name
    grid[py][px + 1] = None

(TS / "house_test_layout.json").write_text(json.dumps({"width": W, "height": H, "cells": grid}))
print(f"Generated {len(tiles)} tiles ({W}x{H} layout) in house_atlas.png + hallway_runner_rug.png + house_test_layout.json")
