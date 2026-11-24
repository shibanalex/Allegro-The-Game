#!/usr/bin/env python3
"""Generate shaped 2D light textures, subtle painterly normal maps, and CanvasTexture .tres wrappers.

Produces:
  - assets/lights/light_radial_smooth.png   (256x256 smooth physically-inspired radial light)
  - assets/lights/light_window_beam.png     (256x256 angled winter window daylight spill cone)
  - assets/lights/light_lamp_cone.png       (256x256 warm tungsten desk lamp cone + soft halo)
  - assets/normals/*_n.png                  (subtle tangent-space 2D normal maps for Godot 4)
  - assets/materials/*_canvas.tres          (CanvasTexture resources linking diffuse + normal maps)
"""
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

ROOT = Path("/home/allegro/allegro-the-game")
LIGHTS_DIR = ROOT / "assets/lights"
NORMALS_DIR = ROOT / "assets/normals"
MATS_DIR = ROOT / "assets/materials"

LIGHTS_DIR.mkdir(parents=True, exist_ok=True)
NORMALS_DIR.mkdir(parents=True, exist_ok=True)
MATS_DIR.mkdir(parents=True, exist_ok=True)


def save_gray_light(arr: np.ndarray, path: Path) -> None:
    """Save [0..1] intensity map as dithered white RGBA light texture (zero 8-bit banding)."""
    rng = np.random.default_rng(1337)
    dither = (rng.random(arr.shape) - 0.5) / 255.0
    v = np.clip(arr + dither, 0.0, 1.0)
    u8 = (v * 255.0 + 0.5).astype(np.uint8)
    rgba = np.stack([u8, u8, u8, u8], axis=-1)
    Image.fromarray(rgba, "RGBA").save(path)


def build_light_textures() -> None:
    N = 256
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    u = (xx + 0.5) / N * 2.0 - 1.0  # [-1, 1]
    v = (yy + 0.5) / N * 2.0 - 1.0  # [-1, 1]
    r = np.sqrt(u * u + v * v)

    # 1. Smooth radial light: bright warm center, gentle wide quadratic falloff, guaranteed zero at r>=0.98
    edge = np.clip(1.0 - np.clip((r - 0.0) / 0.98, 0.0, 1.0), 0.0, 1.0)
    radial = (edge ** 2.15) * (0.35 + 0.65 * np.exp(-r * r * 3.2))
    radial = radial / max(1e-6, radial.max())
    radial[r >= 0.99] = 0.0
    save_gray_light(radial, LIGHTS_DIR / "light_radial_smooth.png")

    # 2. Angled winter window beam: centered at (0,0) = window sill, spills softly downward & slightly right
    #    Keep soft upward ambient bounce around window frame so the window itself stays gently lit!
    vy = (v + 0.25) / 1.25  # 0 near upper sill, 1 at bottom floor
    skew_x = u - np.clip(vy, 0.0, 1.0) * 0.30
    half_w = 0.24 + np.clip(vy, 0.0, 1.0) * 0.34
    horiz = np.exp(-((skew_x / np.maximum(0.08, half_w)) ** 2) * 1.9)
    # Soft vertical envelope: peaks just below sill (v ~ 0.05..0.35), smooth fade down to bottom & gently above sill
    vert_down = np.clip(1.0 - np.clip((v + 0.30) / 1.26, 0.0, 1.0), 0.0, 1.0) ** 1.35
    vert_top = np.clip((v + 0.52) / 0.38, 0.0, 1.0) ** 1.6
    beam = horiz * vert_down * vert_top
    # Blend with subtle circular window bounce so immediate window trim gets soft daylight
    win_bounce = np.exp(-(u * u * 3.8 + (v + 0.22) ** 2 * 4.5)) * 0.55
    win_light = np.clip(beam * 0.92 + win_bounce, 0.0, 1.0)
    # Border safety fade to strict 0 at texture borders
    border = np.clip((1.0 - np.maximum(np.abs(u), np.abs(v))) / 0.14, 0.0, 1.0)
    win_light *= border * border
    win_light = win_light / max(1e-6, win_light.max())
    save_gray_light(win_light, LIGHTS_DIR / "light_window_beam.png")

    # 3. Desk lamp directional cone: shade faces down-left, casting warm pool onto notebook/mug/floor + soft room spill
    #    Origin (0, 0) sits right at bulb mouth.
    dx = u + 0.08 * np.clip(v + 0.1, 0.0, 1.0)  # tilted gently left-down
    cone_w = 0.22 + np.clip(v + 0.15, 0.0, 1.15) * 0.56
    cone_h = np.exp(-((dx / np.maximum(0.08, cone_w)) ** 2) * 1.65)
    cone_v = np.clip((v + 0.25) / 0.25, 0.0, 1.0) * (np.clip(1.0 - np.clip((v + 0.10) / 1.08, 0.0, 1.0), 0.0, 1.0) ** 1.45)
    soft_spill = (np.clip(1.0 - r / 0.96, 0.0, 1.0) ** 2.3) * 0.52
    lamp = np.clip(cone_h * cone_v * 0.85 + soft_spill, 0.0, 1.0)
    lamp *= border * border
    lamp = lamp / max(1e-6, lamp.max())
    save_gray_light(lamp, LIGHTS_DIR / "light_lamp_cone.png")
    print("Generated 3 smooth 2D light textures in assets/lights/")


def make_normal_map(
    src_path: Path,
    out_path: Path,
    strength: float = 0.42,
    blur_sigma: float = 0.65,
    tile_grid: int = 0,
    y_flip: bool = False,
) -> None:
    """Generate clean, non-noisy tangent-space 2D normal map from sprite luminance + alpha silhouette."""
    im = Image.open(src_path).convert("RGBA")
    arr = np.array(im, dtype=np.float32) / 255.0
    rgb = arr[..., :3]
    alpha = arr[..., 3]

    # Perceptual luminance as micro-height map
    lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    # Keep transparent pixels flat so silhouettes don't create wild gradient spikes
    # Fill transparent regions softly with neighboring edge luminance before smoothing
    height = lum.copy()
    mask = alpha > 0.5
    if not mask.all() and mask.any():
        # Gently dome sprites inward from alpha boundary so curved silhouettes catch rim light nicely!
        from scipy.ndimage import distance_transform_edt
        dist = distance_transform_edt(mask).astype(np.float32)
        dome = np.clip(dist / 6.0, 0.0, 1.0)
        dome = np.sqrt(dome)  # soft convex bevel
        height = height * 0.72 + dome * 0.28
        # Neutralize outside height to nearest edge value so Sobel doesn't blow out alpha border
        _, idx = distance_transform_edt(~mask, return_indices=True)
        height = np.where(mask, height, height[idx[0], idx[1]])

    if blur_sigma > 0.0:
        height = gaussian_filter(height, sigma=blur_sigma, mode="nearest")

    # Compute smooth central-difference gradients (per-tile clamped if tile_grid > 0 to avoid cross-tile bleed!)
    gx = np.zeros_like(height)
    gy = np.zeros_like(height)
    if tile_grid > 0:
        H, W = height.shape
        for ty in range(0, H, tile_grid):
            for tx in range(0, W, tile_grid):
                sub = height[ty:ty + tile_grid, tx:tx + tile_grid]
                sh, sw = sub.shape
                sub_p = np.pad(sub, 1, mode="edge")
                gx[ty:ty + sh, tx:tx + sw] = (sub_p[1:-1, 2:] - sub_p[1:-1, :-2]) * 0.5
                gy[ty:ty + sh, tx:tx + sw] = (sub_p[2:, 1:-1] - sub_p[:-2, 1:-1]) * 0.5
    else:
        hp = np.pad(height, 1, mode="edge")
        gx = (hp[1:-1, 2:] - hp[1:-1, :-2]) * 0.5
        gy = (hp[2:, 1:-1] - hp[:-2, 1:-1]) * 0.5

    # Normal vector from height gradient:
    # Godot 4 2D normal maps use OpenGL convention (+X right, +Y up in texture space -> -gy in image coords where y grows down)
    nx = -gx * strength * 4.0
    ny = (gy if y_flip else -gy) * strength * 4.0
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx /= length
    ny /= length
    nz /= length

    # Flatten transparent areas strictly to neutral normal (128, 128, 255)
    if not mask.all():
        nx = np.where(mask, nx, 0.0)
        ny = np.where(mask, ny, 0.0)
        nz = np.where(mask, nz, 1.0)

    r = np.clip((nx * 0.5 + 0.5) * 255.0 + 0.5, 0, 255).astype(np.uint8)
    g = np.clip((ny * 0.5 + 0.5) * 255.0 + 0.5, 0, 255).astype(np.uint8)
    b = np.clip((nz * 0.5 + 0.5) * 255.0 + 0.5, 0, 255).astype(np.uint8)
    a = np.full_like(r, 255)
    Image.fromarray(np.stack([r, g, b, a], axis=-1), "RGBA").save(out_path)


def write_canvas_texture(tres_path: Path, diffuse_res: str, normal_res: str) -> None:
    content = f"""[gd_resource type="CanvasTexture" format=3]

[ext_resource type="Texture2D" path="{diffuse_res}" id="1_diff"]
[ext_resource type="Texture2D" path="{normal_res}" id="2_norm"]

[resource]
diffuse_texture = ExtResource("1_diff")
normal_texture = ExtResource("2_norm")
texture_filter = 1
"""
    tres_path.write_text(content)


def build_normals_and_materials() -> None:
    specs = [
        ("house_atlas", "assets/tilesets/house_atlas.png", 0.52, 0.55, 32),
        ("house_furniture_atlas", "assets/tilesets/house_furniture_atlas.png", 0.40, 0.65, 0),
        ("house_props_atlas", "assets/tilesets/house_props_atlas.png", 0.36, 0.60, 32),
        ("simple_desk", "assets/tilesets/simple_desk.png", 0.42, 0.65, 0),
        ("boy_room_furniture", "assets/tilesets/boy_room_furniture.png", 0.40, 0.65, 0),
        ("hallway_runner_rug", "assets/tilesets/hallway_runner_rug.png", 0.38, 0.55, 0),
        ("hero_allegro_sheet", "assets/characters/hero_allegro_sheet.png", 0.34, 0.70, 48),
        ("kitchen_wall_unit", "assets/tilesets/kitchen_wall_unit.png", 0.42, 0.60, 0),
        ("kitchen_table", "assets/tilesets/kitchen_table.png", 0.40, 0.65, 0),
        ("kitchen_chair_r", "assets/tilesets/kitchen_chair_r.png", 0.38, 0.65, 0),
        ("kitchen_chair_l", "assets/tilesets/kitchen_chair_l.png", 0.38, 0.65, 0),
    ]
    for name, rel_path, strength, sigma, grid in specs:
        src = ROOT / rel_path
        norm_rel = f"assets/normals/{name}_n.png"
        make_normal_map(src, ROOT / norm_rel, strength=strength, blur_sigma=sigma, tile_grid=grid, y_flip=False)
        write_canvas_texture(MATS_DIR / f"{name}_canvas.tres", f"res://{rel_path}", f"res://{norm_rel}")
    print(f"Generated {len(specs)} painterly normal maps + CanvasTexture resources.")


if __name__ == "__main__":
    build_light_textures()
    build_normals_and_materials()
