#!/usr/bin/env python3
"""Build 320x180 4-tone grey-blue ordered Bayer 4x4 dithered bedroom/bed splash & cutscene backgrounds."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

SRC = Path(
    "/home/allegro/.gemini/antigravity/brain/7bd8464a-a6fb-4d91-a857-5dcd24badf98"
    "/modest_wooden_bed_corner_34view_1795098994881.jpg"
)
OUT_DIR = Path("/home/allegro/.gemini/antigravity/brain/7bd8464a-a6fb-4d91-a857-5dcd24badf98")
OUT_FULL = Path("/home/allegro/allegro-the-game/assets/title/bed_intro_bg.png")
OUT_CUTSCENE = Path("/home/allegro/allegro-the-game/assets/title/bed_cutscene_bg.png")

# 4-tone Grey-Blue (серо-синяя) palette matching the reference's ordered-dither photo style
PALETTE_HEX = [
    "#1b2332",  # 0: Deep midnight slate shadow
    "#3c4b66",  # 1: Dark steel-blue mid-shadow
    "#6b7e9c",  # 2: Dusty grey-blue midtone
    "#a5b6cc",  # 3: Flat pale grey-blue highlight / wall
]
PALETTE = np.array(
    [[int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)] for h in PALETTE_HEX],
    dtype=np.uint8,
)

BAYER_4X4 = (
    np.array(
        [
            [0, 8, 2, 10],
            [12, 4, 14, 6],
            [3, 11, 1, 9],
            [15, 7, 13, 5],
        ],
        dtype=np.float32,
    )
    / 16.0
    - 0.5
)


def process_dither(img_gray: Image.Image, w: int, h: int) -> np.ndarray:
    small = img_gray.resize((w, h), Image.LANCZOS)
    small_sharp = small.filter(ImageFilter.UnsharpMask(radius=1.2, percent=145, threshold=2))
    lum = np.asarray(small_sharp, dtype=np.float32) / 255.0
    lum_adj = np.clip((lum - 0.12) / (0.72 - 0.12), 0.0, 1.0) ** 0.94
    bayer = np.tile(BAYER_4X4, (h // 4 + 1, w // 4 + 1))[:h, :w]
    val = lum_adj * 3.0 + bayer * 0.92
    idx = np.clip(np.rint(val), 0, 3).astype(np.int32)
    idx = np.where(lum_adj > 0.91, 3, idx)
    idx = np.where(lum_adj < 0.08, 0, idx)
    return PALETTE[idx]


def main() -> None:
    OUT_FULL.parent.mkdir(parents=True, exist_ok=True)
    src = Image.open(SRC).convert("L")
    sw, sh = src.size

    w, h = 320, 180
    rgb_full = process_dither(src, w, h)
    im_full = Image.fromarray(rgb_full, "RGB")
    im_full.save(OUT_FULL)
    im_full.resize((1280, 720), Image.NEAREST).save(OUT_DIR / "bed_corner_dither_full.png")

    cut_320 = np.zeros((h, w, 3), dtype=np.uint8)
    top_bar, bot_bar = 18, 134
    cropped = src.crop((0, int(sh * 0.05), sw, int(sh * 0.95)))
    cut_320[top_bar:bot_bar, :] = process_dither(cropped, w, bot_bar - top_bar)
    cut_320[top_bar, :] = [216, 226, 238]
    cut_320[bot_bar - 1, :] = [216, 226, 238]
    im_cut = Image.fromarray(cut_320, "RGB")
    im_cut.save(OUT_CUTSCENE)
    im_cut.resize((1280, 720), Image.NEAREST).save(OUT_DIR / "bed_corner_dither_cutscene.png")
    print(f"Saved {OUT_FULL} and {OUT_CUTSCENE}")


if __name__ == "__main__":
    main()
