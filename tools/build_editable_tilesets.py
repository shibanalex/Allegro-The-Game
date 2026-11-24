#!/usr/bin/env python3
"""Assemble clean, strictly 32x32-aligned master editable tilesets and visual grid guides.

Builds:
  - assets/tilesets/house_furniture_atlas.png (320x256, 10x8 of 32x32)
  - assets/tilesets/house_furniture_tiles.json
  - assets/tilesets/house_props_atlas.png (256x64, 8x2 of 32x32)
  - assets/tilesets/house_props_tiles.json
  - assets/tilesets/guides/house_atlas_grid.png
  - assets/tilesets/guides/house_furniture_atlas_grid.png
  - assets/tilesets/guides/house_props_atlas_grid.png
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/home/allegro/allegro-the-game")
TS = ROOT / "assets/tilesets"
GUIDES = TS / "guides"
GUIDES.mkdir(parents=True, exist_ok=True)
T = 32


def build_furniture_atlas() -> tuple[np.ndarray, dict]:
    COLS, ROWS = 10, 8
    atlas = np.zeros((ROWS * T, COLS * T, 4), dtype=np.uint8)
    occupied = np.zeros((ROWS, COLS), dtype=bool)

    boy_furn = np.asarray(Image.open(TS / "boy_room_furniture.png").convert("RGBA"))
    simple_desk = np.asarray(Image.open(TS / "simple_desk.png").convert("RGBA"))
    worn_piano = np.asarray(Image.open(TS / "upright_piano_worn.png").convert("RGBA"))
    kw_unit = np.asarray(Image.open(TS / "kitchen_wall_unit.png").convert("RGBA"))
    k_table = np.asarray(Image.open(TS / "kitchen_table.png").convert("RGBA"))
    k_chair_r = np.asarray(Image.open(TS / "kitchen_chair_r.png").convert("RGBA"))
    k_chair_l = np.asarray(Image.open(TS / "kitchen_chair_l.png").convert("RGBA"))
    runner_rug = np.asarray(Image.open(TS / "hallway_runner_rug.png").convert("RGBA"))
    piano_rug = np.asarray(Image.open(TS / "piano_trio_rug.png").convert("RGBA"))

    def sub(arr: np.ndarray, x: int, y: int, w: int, h: int) -> np.ndarray:
        return arr[y:y + h, x:x + w].copy()

    # Exact 32x32-grid furniture specification:
    # (name, src_arr, col, row, cw, ch, ox, oy, rug, col_rect [x_min, y_min, x_max, y_max] rel to block bottom-center)
    items = [
        ("single_bed", sub(boy_furn, 8, 68, 44, 80), 0, 0, 2, 3, 10, 16, False, [-20, -58, 20, 0]),
        ("simple_desk", simple_desk, 2, 0, 3, 2, 15, 12, False, [-30, -18, 30, 0]),
        ("composer_desk", sub(boy_furn, 80, 8, 66, 52), 5, 0, 3, 2, 15, 12, False, [-30, -18, 30, 0]),
        ("upright_piano", sub(boy_furn, 8, 8, 62, 52), 8, 0, 2, 2, 1, 12, False, [-30, -20, 30, 0]),
        ("stool", sub(boy_furn, 184, 8, 19, 26), 2, 2, 1, 1, 6, 6, False, [-8, -12, 8, 0]),
        ("backpack", sub(boy_furn, 212, 8, 23, 26), 3, 2, 1, 1, 4, 6, False, [-10, -12, 10, 0]),
        ("desk_chair", sub(boy_furn, 156, 8, 19, 42), 4, 2, 1, 2, 6, 22, False, [-8, -10, 7, 0]),
        ("bookcase", sub(boy_furn, 64, 68, 26, 80), 5, 2, 1, 3, 3, 16, False, [-13, -18, 13, 0]),
        ("worn_piano", worn_piano, 6, 2, 2, 2, 1, 12, False, [-30, -20, 30, 0]),
        ("kitchen_chair_r", k_chair_r, 8, 2, 1, 2, 7, 26, False, [-7, -12, 7, 0]),
        ("kitchen_chair_l", k_chair_l, 9, 2, 1, 2, 7, 26, False, [-7, -12, 7, 0]),
        ("kitchen_wall_unit", kw_unit, 0, 3, 3, 3, 10, 24, False, [-38, -20, 38, 0]),
        ("kitchen_table", k_table, 6, 4, 2, 2, 1, 18, False, [-28, -24, 28, 0]),
        ("hallway_runner_rug", runner_rug, 0, 6, 6, 2, 0, 9, True, None),
        ("piano_trio_rug", piano_rug, 6, 6, 4, 2, 3, 1, True, None),
    ]

    tiles = {}
    for name, src_arr, col, row, cw, ch, ox, oy, is_rug, col_rect in items:
        sh, sw = src_arr.shape[:2]
        assert col >= 0 and row >= 0 and col + cw <= COLS and row + ch <= ROWS, f"{name} out of grid"
        assert ox >= 0 and oy >= 0 and ox + sw <= cw * T and oy + sh <= ch * T, (
            f"{name} ({sw}x{sh} @ {ox},{oy}) overflows {cw*T}x{ch*T}"
        )
        assert not occupied[row:row + ch, col:col + cw].any(), f"Cell overlap at {name} ({col},{row},{cw},{ch})"
        occupied[row:row + ch, col:col + cw] = True

        gx0, gy0 = col * T + ox, row * T + oy
        atlas[gy0:gy0 + sh, gx0:gx0 + sw] = src_arr

        tiles[name] = {
            "atlas": [col, row],
            "size": [cw, ch],
            "sprite_size": [sw, sh],
            "paste_offset": [ox, oy],
            "region_rect": [col * T, row * T, cw * T, ch * T],
            "rug": is_rug,
            "col_rect": col_rect,
        }

    Image.fromarray(atlas, "RGBA").save(TS / "house_furniture_atlas.png")
    meta = {"tile_size": T, "grid": [COLS, ROWS], "tiles": tiles}
    (TS / "house_furniture_tiles.json").write_text(json.dumps(meta, indent=1))
    print(f"Built house_furniture_atlas.png ({COLS*T}x{ROWS*T}, {len(tiles)} items)")
    return atlas, meta


def fit_prop_to_cell(cell_48: np.ndarray, bottom_align: bool = True) -> np.ndarray:
    """Tightly crop a 48x48 manor_props sprite and fit cleanly inside 32x32 (scale down ONLY if >30px)."""
    ys, xs = np.where(cell_48[..., 3] > 0)
    if len(ys) == 0:
        return np.zeros((T, T, 4), dtype=np.uint8)
    crop = cell_48[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = crop.shape[:2]
    if w > 30 or h > 30:
        scale = min(30.0 / float(w), 30.0 / float(h))
        nw = max(1, int(round(w * scale)))
        nh = max(1, int(round(h * scale)))
        rgb_rs = np.asarray(
            Image.fromarray(crop[..., :3]).resize((nw, nh), Image.Resampling.LANCZOS),
            dtype=np.uint8,
        )
        a_rs = np.asarray(
            Image.fromarray(crop[..., 3]).resize((nw, nh), Image.Resampling.NEAREST),
            dtype=np.uint8,
        )
        a_mask = a_rs > 128
        crop = np.zeros((nh, nw, 4), dtype=np.uint8)
        crop[a_mask, :3] = rgb_rs[a_mask]
        crop[a_mask, 3] = 255
        h, w = nh, nw
    else:
        a_mask = crop[..., 3] > 128
        crop = crop.copy()
        crop[~a_mask] = 0
        crop[a_mask, 3] = 255

    out = np.zeros((T, T, 4), dtype=np.uint8)
    ox = (T - w) // 2
    oy = (T - h) if bottom_align else (T - h) // 2
    out[oy:oy + h, ox:ox + w] = crop
    return out


def build_props_atlas() -> tuple[np.ndarray, dict]:
    COLS, ROWS = 8, 2
    src = np.asarray(Image.open(TS / "manor_props.png").convert("RGBA"))
    atlas = np.zeros((ROWS * T, COLS * T, 4), dtype=np.uint8)

    # 15 non-empty 48x48 slots mapped 1:1 onto 32x32 grid
    names = [
        ("oil_lamp_lit", 0, 0, True),
        ("oil_lamp_off", 1, 0, True),
        ("book_open", 2, 0, False),
        ("book_closed", 3, 0, False),
        ("book_stack_2", 4, 0, True),
        ("book_stack_3", 5, 0, True),
        ("sheet_loose", 6, 0, False),
        ("note_pinned", 7, 0, False),
        ("notes_double", 0, 1, False),
        ("sheet_pinned_1", 1, 1, False),
        ("sheet_pinned_2", 2, 1, False),
        ("composer_bust", 3, 1, True),
        ("vase_blossom", 4, 1, True),
        ("vase_twigs", 5, 1, True),
        ("petals_scatter", 6, 1, False),
    ]

    tiles = {}
    for name, c, r, bottom_align in names:
        cell48 = src[r * 48:(r + 1) * 48, c * 48:(c + 1) * 48]
        cell32 = fit_prop_to_cell(cell48, bottom_align=bottom_align)
        atlas[r * T:(r + 1) * T, c * T:(c + 1) * T] = cell32
        tiles[name] = {"atlas": [c, r], "size": [1, 1], "bottom_align": bottom_align}

    Image.fromarray(atlas, "RGBA").save(TS / "house_props_atlas.png")
    meta = {"tile_size": T, "grid": [COLS, ROWS], "tiles": tiles}
    (TS / "house_props_tiles.json").write_text(json.dumps(meta, indent=1))
    print(f"Built house_props_atlas.png ({COLS*T}x{ROWS*T}, {len(tiles)} items)")
    return atlas, meta


def render_grid_guide(atlas: np.ndarray, meta_tiles: dict, out_path: Path, scale: int = 2) -> None:
    """Render 2x checkerboard editing reference with 32x32 grid lines & bounding labels."""
    H, W = atlas.shape[:2]
    gw, gh = W * scale, H * scale
    bg = Image.new("RGBA", (gw, gh), (44, 42, 52, 255))
    draw = ImageDraw.Draw(bg)
    step = 16 * scale
    for y in range(0, gh, step):
        for x in range(0, gw, step):
            if ((x // step) + (y // step)) % 2 == 0:
                draw.rectangle([x, y, x + step - 1, y + step - 1], fill=(54, 51, 63, 255))

    up = Image.fromarray(atlas, "RGBA").resize((gw, gh), Image.Resampling.NEAREST)
    bg.alpha_composite(up)
    draw = ImageDraw.Draw(bg)

    cell_px = T * scale
    for gx in range(0, gw, cell_px):
        draw.line([(gx, 0), (gx, gh)], fill=(120, 128, 148, 90), width=1)
    for gy in range(0, gh, cell_px):
        draw.line([(0, gy), (gw, gy)], fill=(120, 128, 148, 90), width=1)

    font = ImageFont.load_default()
    for name, info in meta_tiles.items():
        c, r = info["atlas"]
        cw, ch = info["size"]
        x0, y0 = c * cell_px, r * cell_px
        x1, y1 = (c + cw) * cell_px - 1, (r + ch) * cell_px - 1
        col_box = (110, 195, 165, 190) if info.get("rug") else (225, 175, 110, 190)
        draw.rectangle([x0, y0, x1, y1], outline=col_box, width=1)
        label = f"{name}"
        draw.rectangle([x0 + 2, y0 + 2, min(x1 - 1, x0 + 6 + len(label) * 6), y0 + 13], fill=(18, 18, 24, 200))
        draw.text((x0 + 4, y0 + 2), label, fill=(235, 232, 224, 255), font=font)

    bg.save(out_path)


def main() -> None:
    furn_atlas, furn_meta = build_furniture_atlas()
    props_atlas, props_meta = build_props_atlas()

    arch_atlas = np.asarray(Image.open(TS / "house_atlas.png").convert("RGBA"))
    arch_meta = json.loads((TS / "house_tiles.json").read_text())

    render_grid_guide(arch_atlas, arch_meta["tiles"], GUIDES / "house_atlas_grid.png", scale=2)
    render_grid_guide(furn_atlas, furn_meta["tiles"], GUIDES / "house_furniture_atlas_grid.png", scale=2)
    render_grid_guide(props_atlas, props_meta["tiles"], GUIDES / "house_props_atlas_grid.png", scale=2)
    print(f"Saved grid guides in {GUIDES}")


if __name__ == "__main__":
    main()
