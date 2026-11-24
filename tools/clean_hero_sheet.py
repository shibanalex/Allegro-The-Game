#!/usr/bin/env python3
"""Rebuild hero_allegro_sheet.png side walk strictly from original painterly body/legs + clean contours."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path("/home/allegro/allegro-the-game")
ORIG_BACKUP = Path("/tmp/hero_allegro_sheet_orig.png")
HERO_PATH = ROOT / "assets/characters/hero_allegro_sheet.png"
OUT_ART = Path("/home/allegro/.gemini/antigravity/brain/7bd8464a-a6fb-4d91-a857-5dcd24badf98")

OUTLINE = np.array([20, 15, 15, 255], dtype=np.uint8)
SW_HI = np.array([76, 51, 51, 255], dtype=np.uint8)
SW_MID = np.array([68, 44, 44, 255], dtype=np.uint8)
SW_DARK = np.array([52, 33, 34, 255], dtype=np.uint8)
SKIN_HI = np.array([208, 173, 151, 255], dtype=np.uint8)
SKIN_MID = np.array([184, 148, 128, 255], dtype=np.uint8)
PANTS_HI = np.array([58, 44, 42, 255], dtype=np.uint8)
PANTS_MID = np.array([48, 36, 35, 255], dtype=np.uint8)
PANTS_DARK = np.array([36, 27, 26, 255], dtype=np.uint8)
SHOE_DARK = np.array([28, 21, 21, 255], dtype=np.uint8)


def is_dark_outline(px):
    return (px[..., 3] > 0) & (px[..., :3].max(axis=-1) < 34)


def clean_contour_jaggies(cell: np.ndarray, y_min: int = 4, y_max: int = 47) -> np.ndarray:
    c = cell.copy()
    h, w = c.shape[:2]
    a = c[..., 3] > 0
    pad = np.pad(a, 1)
    nb4 = pad[:-2, 1:-1].astype(int) + pad[2:, 1:-1].astype(int) + pad[1:-1, :-2].astype(int) + pad[1:-1, 2:].astype(int)
    c[a & (nb4 == 0)] = 0

    for _ in range(2):
        a = c[..., 3] > 0
        dark = is_dark_outline(c)
        pa = np.pad(a.astype(int), 1)
        nb4 = pa[:-2, 1:-1] + pa[2:, 1:-1] + pa[1:-1, :-2] + pa[1:-1, 2:]
        nb8 = nb4 + pa[:-2, :-2] + pa[:-2, 2:] + pa[2:, :-2] + pa[2:, 2:]
        spurs = dark & (nb4 <= 1) & (nb8 <= 2)
        spurs[:y_min, :] = False
        spurs[y_max:, :] = False
        c[spurs] = 0

    for y in range(y_min + 1, min(43, y_max - 1)):
        for x in range(1, w - 1):
            if c[y, x, 3] == 0 or not is_dark_outline(c[y:y+1, x:x+1])[0]:
                continue
            for dy, dx in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
                if c[y - dy, x, 3] == 0 and c[y, x - dx, 3] == 0:
                    if (
                        c[y + dy, x, 3] > 0 and is_dark_outline(c[y + dy:y + dy + 1, x:x + 1])[0]
                        and c[y, x + dx, 3] > 0 and is_dark_outline(c[y:y + 1, x + dx:x + dx + 1])[0]
                        and c[y + dy, x + dx, 3] > 0
                    ):
                        c[y, x] = 0
                        break
    return c


def build_clean_left_head(orig: np.ndarray) -> np.ndarray:
    head = orig[48:96, 0:48].copy()
    head[24:, :] = 0
    head[8, 15:18] = 0
    head[8, 17] = OUTLINE
    head[9, 15:17] = 0
    head[9, 17] = OUTLINE
    head[9, 18] = [64, 43, 43, 255]
    head[10, 15] = 0
    head[10, 16] = OUTLINE
    head[10, 17] = [68, 46, 46, 255]
    head[22, 29:] = 0
    head[22, 27] = [44, 31, 31, 255]
    head[22, 28] = OUTLINE
    head[23, 20] = OUTLINE
    head[23, 21:28] = [64, 42, 42, 255]
    head[23, 28] = OUTLINE
    head[23, 29:] = 0
    head[22, 18] = OUTLINE
    head[22, 19:22] = SKIN_HI
    head[23, 19:21] = OUTLINE
    return clean_contour_jaggies(head, 4, 24)


def wrap_outline(cell: np.ndarray, y0: int = 23, y1: int = 47) -> np.ndarray:
    body = cell[y0:y1, :].copy()
    alpha = body[..., 3] > 0
    filled = alpha & (~is_dark_outline(body))
    pad = np.pad(filled, 1)
    adj = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    need_ol = (~alpha) & adj
    body[need_ol] = OUTLINE
    cell[y0:y1, :] = body
    return cell


def clean_step2_from_orig(orig: np.ndarray, head: np.ndarray) -> np.ndarray:
    """Keep orig ROW 1 col 0's exact natural torso/stride (near leg fwd, near arm back) + clean contours."""
    c = orig[48:96, 0:48].copy()
    c[:24, :] = head[:24, :]
    # Round off rear swung hand cleanly (no stray single-pixel tip at x=32)
    c[34:37, 32:] = 0
    c[34:36, 30:32] = SKIN_HI
    c[34:36, 32] = OUTLINE
    c[36, 30:32] = OUTLINE
    c[33, 30:32] = OUTLINE
    # Smooth shoe soles at y=45..46
    c[45, 28:32] = OUTLINE
    c[46, 20:26] = OUTLINE
    return clean_contour_jaggies(c, 4, 47)


def _smooth_back_and_chest(c: np.ndarray) -> None:
    """Make chest and back silhouette smooth & natural without sleeve-stub bump at y=32..33."""
    for y in range(25, 37):
        c[y, 28:] = 0
        back_x = 27 if y < 29 else 28
        c[y, back_x - 1] = SW_MID
        c[y, back_x] = SW_DARK
        c[y, back_x + 1] = OUTLINE
    # Smooth gentle chest slope on left (x=21..23)
    c[27, 21] = SW_HI; c[27, 20] = OUTLINE
    c[28, 21] = SW_HI; c[28, 20] = OUTLINE
    c[29, 20] = SW_HI; c[29, 19] = OUTLINE
    c[30, 20] = SW_HI; c[30, 19] = OUTLINE
    c[31, 20] = SW_HI; c[31, 19] = OUTLINE
    c[32, 20] = SW_MID; c[32, 19] = OUTLINE
    c[33, 20] = SW_MID; c[33, 19] = OUTLINE
    c[34, 20] = SW_DARK; c[34, 19] = OUTLINE
    c[35, 20:28] = SW_DARK


def make_step1_matching_stride(step2: np.ndarray, head: np.ndarray) -> np.ndarray:
    """Same exact torso & leg geometry as step2, swapping leg depth & swinging arm gently forward."""
    c = step2.copy()
    _smooth_back_and_chest(c)

    # Smooth near arm integrated naturally from shoulder (y=26..34) without harsh internal black line
    for y in range(26, 34):
        shift = 0 if y < 28 else (1 if y < 31 else 2)
        x0 = 23 - shift
        c[y, x0:x0 + 3] = SW_HI
        c[y, x0 + 3] = SW_DARK
        if y >= 29:
            c[y, x0 - 1] = OUTLINE
            c[y, x0 + 4] = SW_DARK  # soft fold shadow instead of harsh black cut
    # Soft hand at front-hip
    c[34:36, 20:23] = SKIN_HI
    c[35, 22] = SKIN_MID
    c[33, 20:23] = SW_DARK
    c[36, 20:23] = OUTLINE
    c[34:36, 19] = OUTLINE
    c[34:36, 23] = OUTLINE

    # Swap near/far leg depth on step2's exact natural leg silhouette
    for y in range(37, 46):
        for x in range(17, 25):
            r, g, b, a = c[y, x]
            if a > 0 and max(r, g, b) >= 34:
                c[y, x, :3] = np.clip(np.array([r, g, b]) * 0.78, 22, 255).astype(np.uint8)
        for x in range(26, 34):
            r, g, b, a = c[y, x]
            if a > 0 and max(r, g, b) >= 34:
                c[y, x, :3] = np.clip(np.array([r, g, b]) * 1.24 + 3, 22, 255).astype(np.uint8)

    c[:24, :] = head[:24, :]
    return clean_contour_jaggies(c, 4, 47)


def make_idle_from_step2(step2: np.ndarray, head: np.ndarray) -> np.ndarray:
    """Natural tapered standing IDLE matching hero_tired_sheet proportions in Allegro colors."""
    c = step2.copy()
    _smooth_back_and_chest(c)

    # Relaxed near arm integrated from shoulder (y=26..34) hanging straight down x=23..26
    for y in range(26, 34):
        c[y, 23:26] = SW_HI if y < 32 else SW_MID
        c[y, 26] = SW_DARK
        if y >= 28:
            c[y, 22] = SW_DARK  # soft internal seam
            c[y, 27] = SW_DARK
    c[34:36, 23:26] = SKIN_HI
    c[35, 25] = SKIN_MID
    c[33, 23:26] = SW_DARK
    c[36, 23:26] = OUTLINE
    c[34:36, 22] = OUTLINE
    c[34:36, 26] = OUTLINE

    # Clean tapered standing legs plumb under hip (5px wide thigh -> 4px ankle + neat shoe)
    c[36:48, :] = 0
    for y in range(36, 44):
        x0 = 21 if y < 39 else 22
        x1 = 28 if y < 39 else 27
        c[y, x0:x1] = PANTS_MID
        c[y, x0:x0 + 2] = PANTS_HI
        c[y, x1 - 1] = PANTS_DARK
        if y == 36:
            c[y, x0:x1] = PANTS_DARK
    # Natural shoe with gentle forward toe at y=44..45
    c[44, 21:27] = SHOE_DARK
    c[44, 21:24] = [42, 33, 32, 255]
    c[45, 20:26] = OUTLINE

    c = wrap_outline(c, 24, 47)
    c[:24, :] = head[:24, :]
    return clean_contour_jaggies(c, 4, 47)


def main() -> None:
    orig = np.array(Image.open(ORIG_BACKUP).convert("RGBA"))
    out = orig.copy()

    # Clean ROW 0 (DOWN) and ROW 3 (UP)
    for col in range(3):
        c0 = out[0:48, col * 48:(col + 1) * 48]
        if col == 1:
            c0[33:36, 29:32] = SKIN_MID
            c0[34, 29:31] = SKIN_HI
            c0[32, 29:32] = OUTLINE
            c0[36, 29:32] = OUTLINE
            c0[33:36, 28] = OUTLINE
            c0[33:36, 32] = OUTLINE
        out[0:48, col * 48:(col + 1) * 48] = clean_contour_jaggies(c0, 4, 47)

        c3 = out[144:192, col * 48:(col + 1) * 48]
        c3[23:26, 16:18] = 0
        out[144:192, col * 48:(col + 1) * 48] = clean_contour_jaggies(c3, 4, 47)

    # Side rows (LEFT + mirrored RIGHT)
    left_head = build_clean_left_head(orig)
    step2_left = clean_step2_from_orig(orig, left_head)
    step1_left = make_step1_matching_stride(step2_left, left_head)
    idle_left = make_idle_from_step2(step2_left, left_head)

    left_frames = [idle_left, step1_left, step2_left]
    for col, lf in enumerate(left_frames):
        out[48:96, col * 48:(col + 1) * 48] = lf
        out[96:144, col * 48:(col + 1) * 48] = lf[:, ::-1].copy()

    Image.fromarray(out, "RGBA").save(HERO_PATH)

    # Render 4-frame walk cycle strip [col 1 -> col 0 -> col 2 -> col 0] for LEFT & RIGHT at 6x
    scale = 6
    seq = [1, 0, 2, 0]
    strip = Image.new("RGBA", (48 * 4 * scale, 48 * 2 * scale), (42, 40, 44, 255))
    for i, col in enumerate(seq):
        fl = Image.fromarray(left_frames[col]).resize((48 * scale, 48 * scale), Image.NEAREST)
        fr = Image.fromarray(left_frames[col][:, ::-1]).resize((48 * scale, 48 * scale), Image.NEAREST)
        strip.alpha_composite(fl, (i * 48 * scale, 0))
        strip.alpha_composite(fr, (i * 48 * scale, 48 * scale))
    strip.save(OUT_ART / "hero_side_cycle_strip.png")
    print("Saved cohesive hero_allegro_sheet.png + hero_side_cycle_strip.png")


if __name__ == "__main__":
    main()
