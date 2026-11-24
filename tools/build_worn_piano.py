#!/usr/bin/env python3
"""Create a humbler, slightly worn upright piano sprite from the base furniture sheet."""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path("/home/allegro/allegro-the-game")
TS = ROOT / "assets" / "tilesets"
OUT = Path("/home/allegro/.gemini/antigravity/brain/7bd8464a-a6fb-4d91-a857-5dcd24badf98")

furn = Image.open(TS / "boy_room_furniture.png").convert("RGBA")
orig = np.array(furn.crop((8, 8, 70, 60)), dtype=float)  # (52, 62, 4)
worn = orig.copy()
H, W = worn.shape[:2]  # 52, 62
OUTLINE = np.array([20.0, 15.0, 15.0, 255.0])

# 1. Remove fancy overhanging upper cornice so it reads as a modest straight-sided upright
for y in range(4, 8):
    worn[y, 0] = [0, 0, 0, 0]
    worn[y, 61] = [0, 0, 0, 0]
    worn[y, 1] = OUTLINE
    worn[y, 60] = OUTLINE

# Simpler thinner top lid in 3/4 view (y=1..7, top face slightly paler & drier)
worn[0:2] = 0
worn[2, 1:61] = OUTLINE
worn[3, 2:60] = [94, 72, 54, 255]     # faded top lid plane
worn[4, 2:60] = [84, 63, 47, 255]
worn[5, 2:60] = [62, 46, 35, 255]     # thin front edge of lid
worn[6, 2:60] = [38, 28, 23, 255]     # shadow under lid
worn[7, 2:60] = [48, 36, 28, 255]
for y in range(3, 8):
    worn[y, 1] = OUTLINE
    worn[y, 60] = OUTLINE

# 2. Dry, faded Soviet walnut/birch-stained veneer (less rich dark luxury tone)
is_wood = (
    (worn[..., 3] > 200)
    & (worn[..., 0] < 130)
    & ((worn[..., 0] - worn[..., 2]) > 4)
    & (worn[..., 0] > 28)
)
gray = worn[..., :3].mean(axis=2, keepdims=True)
worn[..., :3] = np.where(
    is_wood[..., None],
    worn[..., :3] * 0.85 + gray * 0.14 + np.array([6.0, 4.0, 2.0]),
    worn[..., :3],
)

# Flatten ornate side moldings on the upper panel
for y in range(8, 25):
    for x in (4, 5, 56, 57):
        if worn[y, x, 3] > 0:
            worn[y, x, :3] = worn[y, 10, :3] * 0.96

# Subtle scuff marks & dry varnish chips (modest, natural)
for cy, cx in ((5, 9), (5, 48), (27, 4), (27, 57), (43, 8)):
    worn[cy, cx, :3] = [112, 89, 68]
worn[39, 13:16, :3] = [94, 75, 58]
worn[40, 15:17, :3] = [86, 68, 54]

# 3. Aged yellowed keys, faded crimson felt tucked behind keys (y=26), no leaking pixels
# Felt strip at y=26 behind white/black keys (keep black keys foreground intact!)
for x in range(5, 57):
    r, g, b, a = worn[26, x]
    if a > 0 and r > 80:  # not black key or shadow
        worn[26, x, :3] = [96, 40, 38]

for y in range(27, 31):
    for x in range(5, 57):
        r, g, b, a = worn[y, x]
        if a > 0 and r > 135 and g > 130 and b > 120:
            key_var = ((x * 7) % 5 - 2) * 2.5
            worn[y, x, :3] = [r * 0.95 + key_var, g * 0.89 + key_var, b * 0.72 + key_var]

# Two slightly sunken/sticky keys strictly within keybed rows y=29..30
worn[29:31, 34, :3] = [132, 118, 92]
worn[29:31, 19, :3] = [138, 122, 96]

# Clean keyboard front lip edge at y=31..32
worn[31, 4:58, :3] = [74, 54, 41]
worn[32, 4:58, :3] = [44, 32, 25]

# 4. Aged, slightly crooked yellowed music book on thin simple desk ledge
for y in range(12, 22):
    for x in range(24, 38):
        if worn[y, x, 0] > 100:
            worn[y, x, :3] = worn[y, x, :3] * np.array([0.97, 0.91, 0.77])
worn[12:14, 36:38, :3] = [110, 96, 76]

# Old worn notebook stack on left of top lid (sitting cleanly on y=2..3)
worn[1, 8:20] = OUTLINE
worn[2, 8] = OUTLINE; worn[2, 9:19] = [154, 140, 112, 255]; worn[2, 19] = OUTLINE
worn[3, 8:20] = [94, 72, 54, 255]
worn[0, 10:18] = OUTLINE
worn[1, 10] = OUTLINE; worn[1, 11:17] = [116, 86, 66, 255]; worn[1, 17] = OUTLINE

# 5. Lower plinth & 2 simple dull pedals (remove 3 ornate pedals cleanly)
for y in range(44, 52):
    for x in range(6, 56):
        if y < 46:
            dist = abs(x - 31)
            fade = max(0.0, 1.0 - dist / 14.0)
            worn[y, x, :3] = np.array([58.0, 44.0, 34.0]) + fade * np.array([15.0, 11.0, 8.0])
            worn[y, x, 3] = 255
        elif y == 46:
            worn[y, x] = OUTLINE
        else:
            worn[y, x] = [0, 0, 0, 0]

# Two simple worn dull-brass pedals emerging from y=46..49
for px in (27, 33):
    worn[47:50, px:px + 3] = OUTLINE
    worn[47, px + 1] = [142, 122, 78, 255]
    worn[48, px + 1] = [104, 88, 56, 255]

worn = np.clip(worn, 0, 255).astype(np.uint8)
out_path = TS / "upright_piano_worn.png"
Image.fromarray(worn, "RGBA").save(out_path)

cmp_img = Image.new("RGBA", (W * 2 + 12, H + 8), (34, 30, 32, 255))
cmp_img.alpha_composite(Image.fromarray(orig.astype(np.uint8), "RGBA"), (4, 4))
cmp_img.alpha_composite(Image.fromarray(worn, "RGBA"), (W + 8, 4))
cmp_img.resize((cmp_img.width * 4, cmp_img.height * 4), Image.NEAREST).save(OUT / "piano_before_after.png")
print("Saved", out_path)