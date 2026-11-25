# Visual Style Guide

## Art Direction

1. World (top-down 3/4): pixel-snapped sprites (`Nearest` filter, `16x16` base grid, `48x48` character cells) with painterly shading inside silhouettes.
2. Dialogue portraits: hand-inked `512x512` portraits in Krita using a 3-4 tone range (sepia paper base, ink contour, charcoal/screentone shadow, sparse warm highlights).
3. Cutscenes: monochrome 4-tone Bayer `4x4` dithered scenes rendered at `320x180`.
4. Lighting: `CanvasModulate` dusk tint paired with directional `PointLight2D` sources and wall `LightOccluder2D` geometry.

## Color Palette (`assets/allegro_sepia_score.gpl`)

- Paper and highlights: `#f4ecd8`, `#e1d4ba`, `#c6b497`, `#9e8b70`
- Ink and walnut wood: `#75604a`, `#524133`, `#362a24`, `#1a1514`
- Cold shadows: `#a8adb0`, `#6c747d`, `#3d424d`, `#21232e`
- Accents (kept below 10% of frame): `#b03636`, `#781c20`, `#d9a661`
