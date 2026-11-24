#!/usr/bin/env python3
"""Extract, harmonize, and pixel-polish kitchen furniture sprites for Allegro: The Game.

Input references (generated in artifact dir):
  - kitchen_wall_unit_ref_1795084271770.jpg -> assets/tilesets/kitchen_wall_unit.png (82x86)
  - kitchen_dining_ref_1795084293607.jpg    -> assets/tilesets/kitchen_table.png (62x46)
                                             -> assets/tilesets/kitchen_chair_r.png (17x38)
                                             -> assets/tilesets/kitchen_chair_l.png (17x38)
"""
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path("/home/allegro/allegro-the-game")
TS = ROOT / "assets/tilesets"
ART_DIR = Path("/home/allegro/.gemini/antigravity/brain/7bd8464a-a6fb-4d91-a857-5dcd24badf98")

WALL_UNIT_REF = ART_DIR / "kitchen_wall_unit_ref_1795084271770.jpg"
DINING_REF = ART_DIR / "kitchen_dining_ref_1795084293607.jpg"
OUTLINE = np.array([20, 15, 15], dtype=np.float32)


def extract_by_border_flood(
    rgb: np.ndarray,
    bg_lum_thresh: float = 236.0,
    bg_chroma_thresh: float = 16.0,
    max_hole_area: int = 24,
) -> tuple[np.ndarray, np.ndarray]:
    """Separate foreground sprite from pure-white background using border-seeded flood fill."""
    f = rgb.astype(np.float32)
    h, w = f.shape[:2]
    lum = f.mean(axis=2)
    chroma = f.max(axis=2) - f.min(axis=2)
    is_bg_candidate = (lum >= bg_lum_thresh) & (chroma <= bg_chroma_thresh)

    visited = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_bg_candidate[y, x] and not visited[y, x]:
                visited[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if is_bg_candidate[y, x] and not visited[y, x]:
                visited[y, x] = True
                q.append((y, x))

    while q:
        cy, cx = q.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and is_bg_candidate[ny, nx]:
                visited[ny, nx] = True
                q.append((ny, nx))

    fg = ~visited

    # Fill tiny interior pinholes accidentally treated as background (< max_hole_area)
    # while keeping large open gaps (under table legs / chair legs) transparent.
    holes = ~fg
    lbl_h, nh = ndimage.label(holes, structure=np.ones((3, 3)))
    if nh > 0:
        counts = np.bincount(lbl_h.ravel())
        border_labels = set(np.unique(np.concatenate([
            lbl_h[0, :], lbl_h[-1, :], lbl_h[:, 0], lbl_h[:, -1]
        ])))
        for hid in range(1, nh + 1):
            if hid not in border_labels and counts[hid] <= max_hole_area:
                fg[lbl_h == hid] = True

    # Keep only largest connected foreground component (removes isolated JPEG dust)
    lbl_fg, nf = ndimage.label(fg, structure=np.ones((3, 3)))
    if nf > 1:
        counts = np.bincount(lbl_fg.ravel())
        counts[0] = 0
        best = int(np.argmax(counts))
        fg = lbl_fg == best

    # Tighten bounding box around clean foreground
    ys, xs = np.where(fg)
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    return rgb[y0:y1, x0:x1], fg[y0:y1, x0:x1]


def resize_and_harmonize(
    crop_rgb: np.ndarray,
    crop_fg: np.ndarray,
    target_w: int,
    target_h: int,
    lum_scale: float = 0.88,
    warm_tint: tuple[float, float, float] = (1.01, 0.99, 0.95),
) -> np.ndarray:
    """Resize RGB via LANCZOS, alpha via NEAREST, harmonize toward game furniture, and seal dark outline."""
    # Pre-replace pure white background bleed right outside foreground with adjacent dark outline color
    # so LANCZOS downsampling never creates pale white fringes inside outer pixels!
    dilated = ndimage.binary_dilation(crop_fg, iterations=4)
    _, nn_idx = ndimage.distance_transform_edt(~crop_fg, return_indices=True)
    clean_rgb = np.where(crop_fg[..., None], crop_rgb, crop_rgb[nn_idx[0], nn_idx[1]])
    # Bias extended halo slightly dark so outer outline pixels stay rich espresso after LANCZOS
    outside_rgb = np.clip(clean_rgb.astype(np.float32) * 0.45 + 20.0 * 0.55, 0, 255).astype(np.uint8)
    clean_rgb = np.where((crop_fg | ~dilated)[..., None], clean_rgb, outside_rgb)

    s_rgb = np.asarray(
        Image.fromarray(clean_rgb).resize((target_w, target_h), Image.Resampling.LANCZOS),
        dtype=np.float32,
    )
    a_u8 = (crop_fg.astype(np.uint8)) * 255
    s_alpha = np.asarray(
        Image.fromarray(a_u8).resize((target_w, target_h), Image.Resampling.NEAREST),
        dtype=np.uint8,
    ) > 128

    # Strip any 1px isolated specks after downsampling
    lbl, n = ndimage.label(s_alpha, structure=np.ones((3, 3)))
    if n > 1:
        counts = np.bincount(lbl.ravel())
        counts[0] = 0
        s_alpha = lbl == int(np.argmax(counts))

    # Strip hairline 1px spurs on bottom legs/outer corners if isolated horizontally and vertically
    pa = np.pad(s_alpha.astype(np.int32), 1)
    nb4 = pa[:-2, 1:-1] + pa[2:, 1:-1] + pa[1:-1, :-2] + pa[1:-1, 2:]
    s_alpha = s_alpha & (nb4 >= 1)

    # Harmonize brightness/sepia warmth toward boy_room_furniture.png / simple_desk.png
    tint = np.array(warm_tint, dtype=np.float32)
    s_rgb = s_rgb * lum_scale * tint[None, None, :]
    # Subtle contrast pull so dark wood shadows sit rich instead of milky
    s_rgb = np.clip((s_rgb - 64.0) * 1.05 + 64.0, 16.0, 224.0)

    # Reinforce outer 1px silhouette contour toward crisp dark espresso [20, 15, 15]
    inner_erode = ndimage.binary_erosion(s_alpha, structure=np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], dtype=bool))
    outer_edge = s_alpha & (~inner_erode)
    s_rgb[outer_edge] = 0.25 * s_rgb[outer_edge] + 0.75 * OUTLINE[None, :]

    out = np.zeros((target_h, target_w, 4), dtype=np.uint8)
    out[s_alpha, :3] = np.clip(s_rgb[s_alpha] + 0.5, 14, 232).astype(np.uint8)
    out[s_alpha, 3] = 255
    return out


def main() -> None:
    # 1. Kitchen wall unit proportioned to 64 px residential wall (76x72 -> sits at y=340, top y=268 below WallTopMap y=256)
    wu_raw = np.asarray(Image.open(WALL_UNIT_REF).convert("RGB"))
    wu_rgb, wu_fg = extract_by_border_flood(wu_raw)
    wu_spr = resize_and_harmonize(wu_rgb, wu_fg, target_w=76, target_h=72, lum_scale=0.84)
    Image.fromarray(wu_spr, "RGBA").save(TS / "kitchen_wall_unit.png")
    print(f"Saved kitchen_wall_unit.png {wu_spr.shape[1]}x{wu_spr.shape[0]}")

    # 2. Dining table & right-facing chair from split sheet
    din_raw = np.asarray(Image.open(DINING_REF).convert("RGB"))
    # Split cleanly through empty white gap between table (x<=825) and chair (x>=1002)
    mid_x = 910
    tbl_raw = din_raw[:, :mid_x]
    chr_raw = din_raw[:, mid_x:]

    tbl_rgb, tbl_fg = extract_by_border_flood(tbl_raw)
    tbl_spr = resize_and_harmonize(tbl_rgb, tbl_fg, target_w=62, target_h=46, lum_scale=0.88)
    Image.fromarray(tbl_spr, "RGBA").save(TS / "kitchen_table.png")
    print(f"Saved kitchen_table.png {tbl_spr.shape[1]}x{tbl_spr.shape[0]}")

    chr_rgb, chr_fg = extract_by_border_flood(chr_raw)
    chr_r_spr = resize_and_harmonize(chr_rgb, chr_fg, target_w=17, target_h=38, lum_scale=0.88)
    chr_l_spr = chr_r_spr[:, ::-1, :].copy()
    Image.fromarray(chr_r_spr, "RGBA").save(TS / "kitchen_chair_r.png")
    Image.fromarray(chr_l_spr, "RGBA").save(TS / "kitchen_chair_l.png")
    print(f"Saved kitchen_chair_r.png & kitchen_chair_l.png {chr_r_spr.shape[1]}x{chr_r_spr.shape[0]}")


if __name__ == "__main__":
    main()
