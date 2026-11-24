#!/usr/bin/env python3
"""Build crisp 320x180 pixelated piano-keys artwork background for the title screen."""
from pathlib import Path
import numpy as np
from PIL import Image

SRC_PATH = Path(
    "/home/allegro/.gemini/antigravity/brain/7bd8464a-a6fb-4d91-a857-5dcd24badf98"
    "/.user_uploaded/media_1795080602061_560f28d9.jpg"
)
OUT_PATH = Path("/home/allegro/allegro-the-game/assets/title/title_piano_bg.png")

W, H = 320, 180
PALETTE_HEX = [
    "#07080d",
    "#12151e",
    "#222733",
    "#383f4d",
    "#545d6d",
    "#747d8c",
    "#979fa9",
    "#b8bec7",
    "#d2d6dc",
]
PALETTE = np.array(
    [[int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)] for h in PALETTE_HEX],
    dtype=np.uint8,
)
PAL_LUM = (0.299 * PALETTE[:, 0] + 0.587 * PALETTE[:, 1] + 0.114 * PALETTE[:, 2]) / 255.0

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
    + 0.5
) / 16.0 - 0.5


def smoothstep(edge0: float, edge1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def main() -> None:
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    src = Image.open(SRC_PATH).convert("L")
    # Crop vertically so diagonal piano keys fill frame proportionally without stretching
    cropped = src.crop((0, 84, src.width, 592))  # 640 x 508
    scaled_w, scaled_h = 226, 180
    resized = cropped.resize((scaled_w, scaled_h), Image.LANCZOS)
    art = np.asarray(resized, dtype=np.float32) / 255.0

    # Subtle contrast curve so blacks stay deep charcoal and strokes stay crisp
    art = np.clip((art - 0.04) / 0.92, 0.0, 1.0)
    art = art ** 1.12

    # Horizontal 36 px smooth feather on left/right artwork edges so keys melt smoothly into obsidian sides
    xs_local = np.arange(scaled_w, dtype=np.float32)[None, :]
    feather_x = smoothstep(0.0, 36.0, xs_local) * smoothstep(0.0, 36.0, (scaled_w - 1) - xs_local)
    art_feathered = art * feather_x

    # Place centered horizontally (x0 = 47) and shifted down slightly (+4 px) onto obsidian canvas
    canvas_lum = np.zeros((H, W), dtype=np.float32)
    x0 = 47
    y_shift = 4
    canvas_lum[y_shift:H, x0:x0 + scaled_w] = art_feathered[: H - y_shift, :]

    # Deeper upper-third scrim (y = 0..84) so the "Allegro" title reads effortlessly over the key tops
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    top_fade = 0.28 + 0.72 * smoothstep(26.0, 84.0, yy)
    canvas_lum *= top_fade

    # Soft center-bottom darkening behind menu box (y = 104..170) while leaving keys dramatic
    box_dy = (yy - 134.0) / 30.0
    box_dx = (xx - 160.0) / 56.0
    box_dist = np.sqrt(box_dx * box_dx + box_dy * box_dy)
    menu_scrim = 0.48 + 0.52 * smoothstep(0.55, 1.35, box_dist)
    canvas_lum *= menu_scrim

    # Ordered 4x4 Bayer dithering & quantization onto 9-step winter-noir slate/ivory palette
    bayer_tiled = np.tile(BAYER_4X4, (H // 4 + 1, W // 4 + 1))[:H, :W]
    dither_strength = 0.065
    # Avoid dithering pure obsidian margins into brighter dots
    active_mask = canvas_lum > 0.015
    dithered = np.where(
        active_mask,
        np.clip(canvas_lum + bayer_tiled * dither_strength, 0.0, 1.0),
        0.0,
    )

    idx = np.abs(dithered[..., None] - PAL_LUM[None, None, :]).argmin(axis=-1)
    rgb = PALETTE[idx]
    alpha = np.full((H, W, 1), 255, dtype=np.uint8)
    rgba = np.concatenate([rgb, alpha], axis=-1)

    Image.fromarray(rgba, "RGBA").save(OUT_PATH)
    print(f"Saved {OUT_PATH} ({W}x{H} RGBA), unique colors: {len(np.unique(idx))}")


if __name__ == "__main__":
    main()
