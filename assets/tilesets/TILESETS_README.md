# Мастер-тайлсеты проекта (сетка 32×32 px)

Все игровые спрайты интерьеров собраны в **три единых атласа с шагом 32×32 px**.  
Каждый атлас можно свободно править в Aseprite, Krita или GIMP, а также рисовать прямо поверх уровня в редакторе Godot.

---

## 1. Три редактируемых PNG-атласа

| Назначение | Файл PNG | Размер | Тайлсет Godot (`.tres`) | Размеченная шпаргалка |
|---|---|---|---|---|
| **Архитектура** (стены, полы, двери, окно, проёмы) | `assets/tilesets/house_atlas.png` | `256×320` (`8×10`) | `assets/tilesets/house_tileset.tres` | `assets/tilesets/guides/house_atlas_grid.png` |
| **Мебель и ковры** (кровати, столы, пианино, кухня, ковры) | `assets/tilesets/house_furniture_atlas.png` | `320×256` (`10×8`) | `assets/tilesets/house_furniture_tileset.tres` | `assets/tilesets/guides/house_furniture_atlas_grid.png` |
| **Мелкий декор** (лампы, книги, ноты, бюст, вазы) | `assets/tilesets/house_props_atlas.png` | `256×64` (`8×2`) | `assets/tilesets/house_props_tileset.tres` | `assets/tilesets/guides/house_props_atlas_grid.png` |

> Все пустые клетки в `house_furniture_atlas.png` и `(7, 1)` в `house_props_atlas.png` специально оставлены свободными под новые предметы.

---

## 2. Слои для расстановки в редакторе Godot (`house_modular.tscn`)

Открой `house_modular.tscn` в Godot и выбирай нужный слой `TileMapLayer`:
- **`HouseMap`** — полы, стены, двери, окна, перегородки.
- **`YSort/WallTopMap`** — верхние срезы южных перегородок (игрок заходит головой за стену).
- **`YSort/FurnitureMap`** — штамповка мебели и ковров из `house_furniture_tileset.tres` (у всех предметов уже настроены Y-Sort и хитбоксы, ковры автоматически кладутся на пол).
- **`YSort/PropsMap`** — расстановка книг, нот, ламп, ваз из `house_props_tileset.tres` поверх столов или полок.

---

## 3. После правки пикселей в PNG

Когда поправишь любой из трёх мастер-PNG в графическом редакторе:
1. Просто обнови карты нормалей (исходные PNG не трогаются):
   ```bash
   python3 /home/allegro/allegro-the-game/tools/sync_normals.py
   ```
2. Если добавишь новый предмет в пустую клетку `house_furniture_atlas.png`, допиши его строку в `tools/build_editable_tilesets.py` / `assets/tilesets/house_furniture_tiles.json` и пересобери `.tres`:
   ```bash
   godot --headless --path /home/allegro/allegro-the-game --import
   godot --headless --path /home/allegro/allegro-the-game --script res://tools/build_furniture_tileset_res.gd
   ```
