# Allegro: The Game

An atmospheric narrative **2D RPG** built in **Godot 4** with an original classical soundtrack, custom GLSL shaders, and a hybrid **Painterly Pixel Art** pipeline in orthogonal `3/4` projection.

## Technical & Artistic Highlights

- **Painterly Pixel Art Pipeline (`tools/`):** Custom Python scripts (`Pillow` / `NumPy`) for perspective deskewing, sepia/walnut palette harmonization (`assets/allegro_sepia_score.gpl`), normal-map syncing, and crisp `1 px` silhouette extraction while preserving painterly interior brushstrokes.
- **Custom Godot Shaders & Atmosphere (`assets/shaders/`, `scripts/`):**
  - Night film grain & vignette shader
  - Monochrome 4-tone Bayer `4×4` dithered cutscene aesthetic (`320×180`)
  - Dynamic 2D lighting, soft shadows (`dynamic_shadow.gd`), and frameless gradient `InteractionBox`
- **Original Classical Score:** Composed in MuseScore 4 and humanized with custom Python continuous-controller (`CC1` / `CC11`) expression scripts.

## Structure

- `scripts/` — Player controller (alternating footstep cadence, pixel-precise movement), atmosphere, cutscenes, audio bus & interaction UI
- `assets/shaders/` — Custom Godot 4 canvas shaders
- `assets/characters/`, `assets/tilesets/` — Original character sprite sheets and room tilesets
- `tools/` — Python & editor scripts for procedural asset/tileset assembly and collision verification
- `*.tscn` — Main room, modular dorm/house, title screen, and intro cutscene scenes
