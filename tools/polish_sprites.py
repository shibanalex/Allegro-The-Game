#!/usr/bin/env python3
"""Surgical pixel-art polish for Allegro: The Game sprites.

Fixes concrete silhouette/cutout imperfections while preserving all internal painterly halftones:
1. simple_desk.png & boy_room_furniture.png (ComposerDesk, SingleBed, Bookcase):
   - Reconstructs the eroded right half of the laptop screen & removes floating shards.
   - Rebuilds the broken brass desk lamp arm/shade cleanly & removes detached specks/blobs.
   - Removes stray single-pixel bumps dangling under the desk front apron.
   - Blends the vertical patch seam on simple_desk.png's left tabletop seamlessly.
   - Cleans stray 1px silhouette spurs on SingleBed and Bookcase.
2. hero_allegro_sheet.png:
   - Closes transparent pinholes under the ear/shoulder/sleeve outlines.
   - Restores a natural subtle right hand in Row 0 Col 2 (Down walk).
   - Aligns Row 1 & Row 2 idle feet cleanly to y=46 (matching walk frames, eliminating 1px bounce).
   - Smooths the protruding 1px chin/mouth spur on side profile heads.
   - Smooths jagged back-of-sweater & rear-heel outline in Row 1/2 Col 2 and sleeve notch in Row 3 Col 1.
"""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path("/home/allegro/allegro-the-game")
OUTLINE = np.array([20, 15, 15, 255], dtype=np.uint8)


def repair_laptop_and_lamp(desk: np.ndarray, blend_left_tabletop: bool = False) -> np.ndarray:
    """Repair eaten laptop screen, broken brass lamp arm, apron bumps, and optional tabletop seam."""
    d = desk.copy()

    # 1. Clear all floating shards & eroded area above the desk surface (y=0..13, x=28..64)
    # Keep y>=14 (tabletop & lamp base & laptop keyboard) intact, rebuild screen + lamp cleanly above y=14
    d[0:14, 28:65] = 0

    # 2. Reconstruct clean Painterly Laptop Screen (x=29..44, y=6..14)
    # Outer dark espresso bezel at x=29, x=44, y=6; inner charcoal bezel at x=30, x=43, y=7, y=13
    bezel_in = np.array([38, 36, 42, 255], dtype=np.uint8)
    hinge_col = np.array([56, 52, 54, 255], dtype=np.uint8)

    d[6, 29:45] = OUTLINE
    d[6:15, 29] = OUTLINE
    d[6:15, 44] = OUTLINE
    d[7, 30:44] = bezel_in
    d[7:14, 30] = bezel_in
    d[7:14, 43] = bezel_in
    d[13, 30:44] = bezel_in
    d[14, 30:44] = hinge_col

    # Painterly glowing dark-blue/teal code & music-DAW screen interior (x=31..42, y=8..12)
    for y in range(8, 13):
        for x in range(31, 43):
            ty = (y - 8) / 4.0
            tx = (x - 31) / 11.0
            # Soft cool midnight-teal screen glow (brighter toward center)
            glow = 1.0 - 0.35 * (((tx - 0.45) ** 2 + (ty - 0.45) ** 2) ** 0.5)
            r = int(np.clip((38 + 18 * (1 - tx)) * glow, 24, 95))
            g = int(np.clip((68 + 38 * tx * (1 - 0.4 * ty)) * glow, 44, 135))
            b = int(np.clip((96 + 44 * (1 - 0.3 * tx)) * glow, 68, 168))
            d[y, x] = [r, g, b, 255]

    # Subtle glowing UI/DAW track bars on the laptop screen
    d[9, 32:37] = [96, 148, 178, 255]
    d[9, 38:41] = [112, 168, 144, 255]
    d[10, 33:40] = [74, 126, 152, 255]
    d[11, 32:36] = [118, 142, 186, 255]
    d[11, 37:42] = [88, 148, 132, 255]
    # Crisp 1px screen edge highlight at top-left
    d[8, 31:35] = [82, 118, 152, 255]

    # 3. Reconstruct clean Painterly Brass Desk Lamp (x=47..62, y=1..14, connecting cleanly to base at x=54..61, y=14..18)
    brass_hi = np.array([218, 182, 112, 255], dtype=np.uint8)
    brass_mid = np.array([156, 122, 72, 255], dtype=np.uint8)
    brass_dk = np.array([94, 70, 44, 255], dtype=np.uint8)
    bulb_core = np.array([250, 236, 184, 255], dtype=np.uint8)
    bulb_warm = np.array([232, 198, 126, 255], dtype=np.uint8)

    # Vertical brass stem rising cleanly from lamp base center (x=57..58, y=5..14)
    for y in range(5, 15):
        d[y, 56] = OUTLINE
        d[y, 57] = brass_hi if y % 3 != 0 else brass_mid
        d[y, 58] = brass_dk
        d[y, 59] = OUTLINE
    # Upper angled arm from top joint (57, 4) over to shade mount (53, 2)
    arm_pts = [(57, 4), (56, 3), (55, 3), (54, 2)]
    for ax, ay in arm_pts:
        d[ay - 1, ax] = OUTLINE
        d[ay + 1, ax] = OUTLINE
        d[ay, ax] = brass_mid
    d[3, 56] = brass_hi
    d[4, 58] = OUTLINE
    d[3, 57] = OUTLINE
    d[2, 55] = OUTLINE

    # Angled brass dome lampshade facing down-left toward desk & mug (x=47..55, y=1..10)
    # Build pixel-by-pixel painterly dome with crisp 1px dark espresso contour
    shade_rows = {
        1: (52, 54),
        2: (51, 55),
        3: (49, 55),
        4: (48, 55),
        5: (47, 54),
        6: (47, 54),
        7: (47, 53),
        8: (48, 53),
        9: (49, 52),
    }
    for y, (x0, x1) in shade_rows.items():
        for x in range(x0, x1 + 1):
            if y == 1 or x == x0 or x == x1 or (y == 9):
                d[y, x] = OUTLINE
            else:
                # Upper-right side is brass shell; lower-left opening reveals warm glowing bulb
                if (y >= 5 and x <= 51) or (y >= 6 and x <= 52):
                    dist_bulb = abs(x - 50) + abs(y - 6.5)
                    d[y, x] = bulb_core if dist_bulb <= 1.6 else bulb_warm
                elif y <= 4 and x <= 52:
                    d[y, x] = brass_hi
                elif x >= 53:
                    d[y, x] = brass_dk
                else:
                    d[y, x] = brass_mid

    # Ensure crisp outer contour around dome top/bottom corners without floating dots
    d[2, 50] = OUTLINE
    d[3, 48] = OUTLINE
    d[4, 47] = OUTLINE
    d[7, 54] = OUTLINE
    d[8, 54] = OUTLINE
    d[9, 53] = OUTLINE

    # Warm gentle tabletop highlight refresh right at lamp base junction (y=14, x=56..59)
    d[14, 57] = brass_hi
    d[14, 58] = brass_mid

    # 4. Remove the two stray dark 1px bumps dangling under front desk apron (y=35, x=30..50)
    d[35, 25:52] = 0

    # 5. For simple_desk.png, smoothly blend the patched left tabletop seam (x=7..28, y=15..31)
    if blend_left_tabletop:
        # Remove the harsh dark horizontal streak at y=18..19 on the left side & blend vertical seam at x=27..29
        # Sample clean horizontal walnut grain color per row from x=29..32 (just left of laptop) & blend gently
        rng = np.random.default_rng(19)
        for y in range(15, 32):
            # Reference wood tone on left edge (x=8..14) vs right of seam (x=28..30)
            left_ref = d[y, 9:16, :3].astype(float).mean(axis=0)
            # Soften the dark groove at y=18..19 using average of y=17 and y=20
            if y in (18, 19):
                above = d[17, 7:29, :3].astype(float)
                below = d[20, 7:29, :3].astype(float)
                blended = above * 0.45 + below * 0.55
                for x in range(7, 29):
                    grain = (rng.random() - 0.5) * 4.5
                    # Slight subtle plank seam at y=19 only (very soft, not a black bar)
                    darken = 0.92 if y == 19 else 0.98
                    d[y, x, :3] = np.clip(blended[x - 7] * darken + grain, 20, 255).astype(np.uint8)
            # Smooth the vertical jump across x=25..29 (where MIDI keyboard patch met original warm tabletop)
            if y >= 15 and y <= 31:
                for x in range(23, 29):
                    if d[y, x, 3] > 0 and d[y, 29, 3] > 0:
                        t = (x - 22) / 7.0
                        t = t * t * (3.0 - 2.0 * t)
                        # Only blend wood pixels (avoid laptop dark bezel at x=28..29, y<=22)
                        right_px = d[y, 29, :3].astype(float)
                        if right_px.max() > 65:
                            cur = d[y, x, :3].astype(float)
                            d[y, x, :3] = np.clip(cur * (1.0 - 0.55 * t) + right_px * (0.55 * t), 20, 255).astype(np.uint8)

    return d


def polish_furniture_sheet() -> None:
    # 1. simple_desk.png
    desk_path = ROOT / "assets/tilesets/simple_desk.png"
    desk = np.array(Image.open(desk_path).convert("RGBA"))
    desk_fixed = repair_laptop_and_lamp(desk, blend_left_tabletop=True)
    Image.fromarray(desk_fixed, "RGBA").save(desk_path)

    # 2. boy_room_furniture.png
    furn_path = ROOT / "assets/tilesets/boy_room_furniture.png"
    furn = np.array(Image.open(furn_path).convert("RGBA"))

    # Fix ComposerDesk at Rect2(80, 8, 66, 52)
    comp_desk = furn[8:60, 80:146].copy()
    furn[8:60, 80:146] = repair_laptop_and_lamp(comp_desk, blend_left_tabletop=False)

    # Fix Bookcase stray 1px dark dot hanging at bottom edge (Rect2(64, 68, 26, 80))
    # Clear any isolated 1px pixel on row y=147 that has no left/right neighbor
    for x in range(64, 90):
        if furn[147, x, 3] > 0:
            left_a = furn[147, x - 1, 3] > 0 if x > 64 else False
            right_a = furn[147, x + 1, 3] > 0 if x < 89 else False
            if not left_a and not right_a:
                furn[147, x] = 0

    # Clean isolated 1px dark spurs sticking out horizontally on SingleBed outer sides (Rect2(8, 68, 44, 80))
    bed = furn[68:148, 8:52].copy()
    a = bed[..., 3] > 0
    for y in range(2, 78):
        for x in range(1, 43):
            if a[y, x] and bed[y, x, :3].max() < 34:
                nb4 = int(a[y - 1, x]) + int(a[y + 1, x]) + int(a[y, x - 1]) + int(a[y, x + 1])
                if nb4 <= 1:
                    bed[y, x] = 0
    furn[68:148, 8:52] = bed

    Image.fromarray(furn, "RGBA").save(furn_path)
    print("Polished simple_desk.png and boy_room_furniture.png")


def polish_hero_sheet() -> None:
    hero_path = ROOT / "assets/characters/hero_allegro_sheet.png"
    hero = np.array(Image.open(hero_path).convert("RGBA"))

    SW_HI = np.array([76, 51, 51, 255], dtype=np.uint8)
    SW_MID = np.array([66, 43, 43, 255], dtype=np.uint8)
    SW_DARK = np.array([50, 32, 33, 255], dtype=np.uint8)
    SKIN_HI = np.array([208, 173, 151, 255], dtype=np.uint8)
    SKIN_MID = np.array([180, 144, 124, 255], dtype=np.uint8)
    SHOE_TOP = np.array([42, 33, 32, 255], dtype=np.uint8)
    SHOE_DARK = np.array([28, 21, 21, 255], dtype=np.uint8)

    # --- ROW 0 (DOWN): cols 0, 1, 2 ---
    for c in range(3):
        cell = hero[0:48, c * 48:(c + 1) * 48]
        # Close transparent 1px pinhole under left hair/cheek at (18, 20)
        cell[20, 18] = OUTLINE
        if c == 1:
            # Close transparent 1px shoulder notch at (31, 26)
            cell[26, 31] = SW_DARK
            cell[26, 32] = OUTLINE
        elif c == 2:
            # Clean ragged right-sleeve outer notch at (32, 29) & restore balanced subtle back-swung right hand
            cell[29, 32] = SW_DARK
            cell[29, 33] = OUTLINE
            cell[33, 30:33] = SW_DARK
            cell[33, 33] = OUTLINE
            cell[34, 30:32] = SKIN_MID
            cell[34, 32] = OUTLINE
            cell[35, 30:32] = OUTLINE
            cell[35, 32] = 0
            cell[34, 33] = 0

    # --- ROW 1 (LEFT) & ROW 2 (RIGHT, mirrored) ---
    for c in range(3):
        cell = hero[48:96, c * 48:(c + 1) * 48].copy()
        # Soften 1px protruding nose/mouth dark pixel at (17, 21) -> cleaner side profile
        cell[21, 17] = 0

        if c == 0:
            # Extend idle standing shoe cleanly to y=46 so idle & walk share exact y=[5..46] baseline!
            cell[44, 21:24] = SHOE_TOP
            cell[44, 24:27] = SHOE_DARK
            cell[44, 20] = OUTLINE
            cell[44, 27] = OUTLINE
            cell[45, 20:27] = SHOE_DARK
            cell[45, 21:24] = [34, 26, 26, 255]
            cell[45, 19] = OUTLINE
            cell[45, 27] = OUTLINE
            cell[46, 20:27] = OUTLINE
        elif c == 2:
            # Smooth jagged back-of-sweater contour (y=26..34) & rear heel spur (y=43..45)
            cell[26, 30] = SW_DARK
            cell[26, 31] = OUTLINE
            cell[27, 30] = SW_MID
            cell[27, 31] = OUTLINE
            cell[27, 32] = 0
            cell[28, 30] = SW_MID
            cell[28, 31] = OUTLINE
            cell[29, 31] = SW_DARK
            cell[29, 32] = OUTLINE
            cell[30, 31] = SW_DARK
            cell[30, 32] = OUTLINE
            cell[30, 33] = 0
            cell[31, 32] = SW_DARK
            cell[31, 33] = OUTLINE
            cell[32, 32] = SW_DARK
            cell[32, 33] = OUTLINE
            cell[32, 34] = 0
            cell[33, 33] = OUTLINE
            cell[33, 34] = 0
            # Clean rear-swung hand cleanly at (30..32, 34..35)
            cell[34, 30:32] = SKIN_HI
            cell[34, 32] = OUTLINE
            cell[34, 33] = 0
            cell[35, 30:32] = SKIN_MID
            cell[35, 32] = OUTLINE
            cell[36, 30:32] = OUTLINE
            # Smooth jagged rear shoe spur at (34, 43)
            cell[43, 34] = 0
            cell[44, 34] = OUTLINE

        hero[48:96, c * 48:(c + 1) * 48] = cell
        hero[96:144, c * 48:(c + 1) * 48] = cell[:, ::-1].copy()

    # --- ROW 3 (UP): cols 0, 1, 2 ---
    c1 = hero[144:192, 48:96]
    # Close ragged outer right-sleeve notch at (32, 29)
    c1[29, 32] = SW_DARK
    c1[29, 33] = OUTLINE

    Image.fromarray(hero, "RGBA").save(hero_path)
    print("Polished hero_allegro_sheet.png")


if __name__ == "__main__":
    polish_furniture_sheet()
    polish_hero_sheet()
