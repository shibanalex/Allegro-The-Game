extends Node2D
## 100% аутентичное воспроизведение RPG Maker MV (rpg_core.js / rpg_windows.js / rpg_scenes.js):
## 1. Нативное окно 816x624 (1:1 без дробного скейла) + родной шрифт mplus-1m-regular.ttf (GameFont)
## 2. Строгое поклеточное движение по сетке 48x48 (4 направления, шаг из клетки в клетку)
## 3. Пружинистое раскрытие окна диалога по вертикали (openness 0 -> 1 за 8 кадров)
## 4. Правильный тайлинг паттерна Window.png (96x96 без растяжения) и чистый экран карты без лишних плашек
## 5. Настоящая геометрия комнаты RPG Maker MV: потолочный срез стен (Inside_A4), 2-клеточная стена и 24px тень слева

const TILE := 48
const MAP_COLS := 17 # 816 px
const MAP_ROWS := 13 # 624 px
const MOVE_SPEED := 240.0 # ~5 клеток в секунду (скорость 4 в RMMV)

enum State { EXPLORE, DIALOG, CHOICE, MENU }
var state: State = State.EXPLORE

# Поклеточные координаты персонажа (в тайлах 0..16, 0..12)
var grid_col := 8
var grid_row := 8
var target_col := 8
var target_row := 8
var pixel_pos := Vector2(8 * TILE, 8 * TILE)
var player_dir := 0 # 0: down, 1: left, 2: right, 3: up
var is_stepping := false
var step_anim_phase := 0.0
var step_pattern := 1
var ui_time := 0.0
var play_seconds := 0.0
var steps_count := 0

# Диалоговая система с анимацией openness (0.0 -> 1.0 как в Window_Base)
var dialog_queue: Array[Dictionary] = []
var current_line := ""
var current_speaker := ""
var current_face_index := 4
var visible_chars := 0.0
var window_openness := 0.0
var closing_dialog := false

# Окно выбора (Window_ChoiceList)
var choices: Array[String] = []
var choice_index := 0
var choice_callback: Callable

# Команды меню Scene_Menu
var menu_items: Array[String] = [
	"Предметы",
	"Навыки",
	"Экипировка",
	"Статус",
	"Сменить BGM",
	"Сохранить",
	"Конец игры"
]
var menu_index := 0
var has_sheet_music := false

# Ресурсы RPG Maker MV
var game_font: Font
var tex_window: Texture2D
var tex_icons: Texture2D
var tex_actor: Texture2D
var tex_faces: Texture2D
var tex_a4: Texture2D
var tex_a5: Texture2D
var tex_b: Texture2D
var tex_c: Texture2D

# Карта непроходимых клеток и интерактивных объектов (в координатах сетки col, row)
var blocked_cells := {}
var event_cells := {}


func _ready() -> void:
	game_font = load("res://assets/rmmv/fonts/mplus-1m-regular.ttf")
	tex_window = load("res://assets/rmmv/img/system/Window.png")
	tex_icons = load("res://assets/rmmv/img/system/IconSet.png")
	tex_actor = load("res://assets/rmmv/img/characters/Actor1.png")
	tex_faces = load("res://assets/rmmv/img/faces/Actor1.png")
	tex_a4 = load("res://assets/rmmv/img/tilesets/Inside_A4.png")
	tex_a5 = load("res://assets/rmmv/img/tilesets/Inside_A5.png")
	tex_b = load("res://assets/rmmv/img/tilesets/Inside_B.png")
	tex_c = load("res://assets/rmmv/img/tilesets/Inside_C.png")

	_setup_collision_and_events()
	pixel_pos = Vector2(grid_col * TILE, grid_row * TILE)

	SFX.using_rmmv_bgm = true
	SFX.play_bgm()

	start_dialog([
		{
			"speaker": "Алексей",
			"face": 4,
			"text": "Я исправила все микродетали, которые выдавали подделку:\n• Родной шрифт mplus-1m-regular.ttf и окно 1:1 (816×624)\n• Поклеточный шаг по сетке 48×48 и раскрытие окна диалога по вертикали"
		},
		{
			"speaker": "Алексей",
			"face": 4,
			"text": "• Настоящие стены с потолочным срезом из Inside_A4 и классической тенью 24px слева\n• Правильный тайлинг полосок Window.png и тихий быстрый вывод текста без пищалки."
		}
	])


func _setup_collision_and_events() -> void:
	# Книжные шкафы (cols 3..6, row 4)
	for c in range(3, 7):
		blocked_cells[Vector2i(c, 4)] = true
		event_cells[Vector2i(c, 4)] = "bookshelf"
	# Камин (cols 7..9, row 4)
	for c in range(7, 10):
		blocked_cells[Vector2i(c, 4)] = true
		event_cells[Vector2i(c, 4)] = "fireplace"
	# Пианино (cols 10..11, row 4)
	for c in range(10, 12):
		blocked_cells[Vector2i(c, 4)] = true
		event_cells[Vector2i(c, 4)] = "piano"
	# Орган (cols 12..13, row 4)
	for c in range(12, 14):
		blocked_cells[Vector2i(c, 4)] = true
		event_cells[Vector2i(c, 4)] = "organ"
	# Стол с нотами и стулья (cols 4..5, row 7 и стул col 4, row 6)
	blocked_cells[Vector2i(4, 7)] = true
	blocked_cells[Vector2i(5, 7)] = true
	event_cells[Vector2i(4, 7)] = "table"
	event_cells[Vector2i(5, 7)] = "table"
	# Кровать (cols 12..13, rows 7..8)
	for r in range(7, 9):
		for c in range(12, 14):
			blocked_cells[Vector2i(c, r)] = true
			event_cells[Vector2i(c, r)] = "bed"


func _is_passable(col: int, row: int) -> bool:
	# Внутренний пол комнаты: столбцы 2..14, строки 4..10
	if col < 2 or col > 14 or row < 4 or row > 10:
		return false
	return not blocked_cells.has(Vector2i(col, row))


func _process(delta: float) -> void:
	ui_time += delta
	play_seconds += delta

	# Плавное открытие / закрытие окна диалога (как Window_Base._updateOpen / _updateClose в RMMV)
	if state in [State.DIALOG, State.CHOICE] and not closing_dialog:
		window_openness = move_toward(window_openness, 1.0, delta * 7.5)
	elif closing_dialog:
		window_openness = move_toward(window_openness, 0.0, delta * 7.5)
		if window_openness <= 0.0:
			closing_dialog = false
			state = State.EXPLORE

	match state:
		State.EXPLORE:
			_process_grid_movement(delta)
		State.DIALOG:
			if window_openness >= 0.99 and not closing_dialog:
				_process_dialog(delta)

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode

	var is_confirm := key in [KEY_Z, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	var is_cancel := key in [KEY_X, KEY_ESCAPE, KEY_BACKSPACE]
	var is_up := key in [KEY_UP, KEY_W]
	var is_down := key in [KEY_DOWN, KEY_S]

	match state:
		State.EXPLORE:
			if is_stepping:
				return
			if is_confirm:
				_try_interact()
			elif is_cancel:
				SFX.play_decision()
				menu_index = 0
				state = State.MENU

		State.DIALOG:
			if closing_dialog or window_openness < 0.9:
				return
			if is_confirm or is_cancel:
				if int(visible_chars) < current_line.length():
					visible_chars = float(current_line.length())
				else:
					_advance_dialog()

		State.CHOICE:
			if is_up:
				choice_index = (choice_index - 1 + choices.size()) % choices.size()
				SFX.play_cursor()
			elif is_down:
				choice_index = (choice_index + 1) % choices.size()
				SFX.play_cursor()
			elif is_confirm:
				SFX.play_decision()
				var picked := choice_index
				closing_dialog = true
				if choice_callback.is_valid():
					choice_callback.call(picked)
			elif is_cancel:
				SFX.play_cancel()
				closing_dialog = true

		State.MENU:
			if is_up:
				menu_index = (menu_index - 1 + menu_items.size()) % menu_items.size()
				SFX.play_cursor()
			elif is_down:
				menu_index = (menu_index + 1) % menu_items.size()
				SFX.play_cursor()
			elif is_cancel:
				SFX.play_cancel()
				state = State.EXPLORE
			elif is_confirm:
				_activate_menu_item(menu_index)


func _process_grid_movement(delta: float) -> void:
	if is_stepping:
		var target_px := Vector2(target_col * TILE, target_row * TILE)
		pixel_pos = pixel_pos.move_toward(target_px, MOVE_SPEED * delta)
		step_anim_phase += delta * 9.0
		var cycle := [1, 2, 1, 0]
		step_pattern = cycle[int(step_anim_phase) % 4]
		if pixel_pos.distance_to(target_px) < 0.5:
			pixel_pos = target_px
			grid_col = target_col
			grid_row = target_row
			is_stepping = false
		return

	# Проверяем зажатую клавишу направления (строго 4 стороны, без диагоналей, как в RPG Maker MV)
	var d_col := 0
	var d_row := 0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		d_row = 1
		player_dir = 0
	elif Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		d_col = -1
		player_dir = 1
	elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		d_col = 1
		player_dir = 2
	elif Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		d_row = -1
		player_dir = 3
	else:
		step_pattern = 1
		return

	var next_c := grid_col + d_col
	var next_r := grid_row + d_row
	if _is_passable(next_c, next_r):
		target_col = next_c
		target_row = next_r
		is_stepping = true
		steps_count += 1
	else:
		step_pattern = 1


func _facing_cell() -> Vector2i:
	match player_dir:
		0: return Vector2i(grid_col, grid_row + 1)
		1: return Vector2i(grid_col - 1, grid_row)
		2: return Vector2i(grid_col + 1, grid_row)
		3: return Vector2i(grid_col, grid_row - 1)
	return Vector2i(grid_col, grid_row)


func _try_interact() -> void:
	var cell := _facing_cell()
	if not event_cells.has(cell):
		return
	var ev_id: String = event_cells[cell]
	match ev_id:
		"piano":
			start_dialog([
				{
					"speaker": "Алексей",
					"face": 4,
					"text": "Чёрное кабинетное пианино. На пюпитре открыта рукопись «Фортепианного трио фа минор».",
					"choices": [
						"Играть Town1.ogg (RPG Maker MV)",
						"Играть Nocturne in F minor",
						"Забрать партитуру в инвентарь",
						"Отойти"
					],
					"callback": _on_piano_choice
				}
			])
		"organ":
			SFX.play_equip()
			start_dialog([
				{
					"speaker": "Алексей",
					"face": 4,
					"text": "Кабинетный духовой орган с двумя мануалами и педалями."
				}
			])
		"bookshelf":
			SFX.play_book()
			start_dialog([
				{
					"speaker": "Алексей",
					"face": 4,
					"text": "Шкаф с партитурами Шостаковича, Рахманинова и учебниками по контрапункту."
				}
			])
		"fireplace":
			start_dialog([
				{
					"speaker": "Алексей",
					"face": 4,
					"text": "В каменном камине потрескивают дрова."
				}
			])
		"table":
			SFX.play_book()
			start_dialog([
				{
					"speaker": "Алексей",
					"face": 4,
					"text": "На столе раскрыта нотная тетрадь, чернильница с пером и горячий чай."
				}
			])
		"bed":
			start_dialog([
				{
					"speaker": "Алексей",
					"face": 4,
					"text": "Кровать аккуратно заправлена."
				}
			])


func _on_piano_choice(idx: int) -> void:
	match idx:
		0:
			SFX.using_rmmv_bgm = true
			SFX.play_bgm()
		1:
			SFX.using_rmmv_bgm = false
			SFX.play_bgm()
		2:
			has_sheet_music = true
			SFX.play_equip()
			start_dialog([
				{
					"speaker": "",
					"face": 4,
					"text": "Получено: «Партитура Фортепианного трио фа минор»!"
				}
			])


func _activate_menu_item(idx: int) -> void:
	match idx:
		0, 1, 2, 3, 5:
			SFX.play_decision()
		4:
			SFX.play_equip()
			SFX.toggle_bgm_source()
		6:
			SFX.play_cancel()
			state = State.EXPLORE


func start_dialog(lines: Array[Dictionary]) -> void:
	dialog_queue = lines.duplicate()
	closing_dialog = false
	window_openness = 0.0
	_advance_dialog()


func _advance_dialog() -> void:
	if dialog_queue.is_empty():
		closing_dialog = true
		return
	var entry: Dictionary = dialog_queue.pop_front()
	current_speaker = entry.get("speaker", "")
	var raw_text: String = entry.get("text", "")
	current_line = (current_speaker + ":\n" + raw_text) if current_speaker != "" else raw_text
	current_face_index = entry.get("face", 4)
	visible_chars = 0.0
	state = State.DIALOG
	if entry.has("choices"):
		choices = []
		for c in entry["choices"]:
			choices.append(str(c))
		choice_index = 0
		choice_callback = entry.get("callback", Callable())
	else:
		choices = []


func _process_dialog(delta: float) -> void:
	if int(visible_chars) < current_line.length():
		# В RPG Maker MV текст выводится по 1-2 символа за кадр (60-90 симв/сек) БЕЗ звука пищалки
		visible_chars += delta * 75.0
	elif not choices.is_empty() and state == State.DIALOG:
		state = State.CHOICE


# ============================================================================
# КАНОНИЧНЫЙ РЕНДЕРЕР WINDOW.PNG ПО АЛГОРИТМУ RPG_CORE.JS (Window.prototype)
# ============================================================================

func _draw_rmmv_window(rect: Rect2, openness: float = 1.0) -> void:
	if tex_window == null or openness <= 0.01:
		return

	# В RPG Maker MV openness масштабирует окно по вертикали относительно его центра
	var h_open := rect.size.y * clampf(openness, 0.0, 1.0)
	var y_open := rect.position.y + (rect.size.y - h_open) * 0.5
	var r := Rect2(rect.position.x, y_open, rect.size.x, h_open)
	if r.size.y < 8.0:
		return

	var m := 4.0
	var back_rect := r.grow(-m)
	if back_rect.size.x > 0 and back_rect.size.y > 0:
		# 1. Градиентная подложка (0, 0, 96, 96) с фирменным тоном RMMV (opacity = 192/255)
		draw_texture_rect_region(tex_window, back_rect, Rect2(0, 0, 96, 96), Color(0.28, 0.34, 0.46, 0.86))

		# 2. Тайлинг (БЕЗ растяжения!) паттерна полосок (0, 96, 96, 96) шагом 96x96
		var bx0 := back_rect.position.x
		var by0 := back_rect.position.y
		var bx1 := back_rect.end.x
		var by1 := back_rect.end.y
		var ty := by0
		while ty < by1:
			var th := minf(96.0, by1 - ty)
			var tx := bx0
			while tx < bx1:
				var tw := minf(96.0, bx1 - tx)
				draw_texture_rect_region(
					tex_window,
					Rect2(tx, ty, tw, th),
					Rect2(0, 96, tw, th),
					Color(1, 1, 1, 0.38)
				)
				tx += 96.0
			ty += 96.0

	# 3. 9-slice рамка из (96, 0, 96, 96), углы 24x24
	var c := minf(24.0, r.size.y * 0.5)
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y

	draw_texture_rect_region(tex_window, Rect2(x, y, c, c), Rect2(96, 0, c, c))
	draw_texture_rect_region(tex_window, Rect2(x + w - c, y, c, c), Rect2(96 + 96 - c, 0, c, c))
	draw_texture_rect_region(tex_window, Rect2(x, y + h - c, c, c), Rect2(96, 96 - c, c, c))
	draw_texture_rect_region(tex_window, Rect2(x + w - c, y + h - c, c, c), Rect2(96 + 96 - c, 96 - c, c, c))

	if w > c * 2.0:
		draw_texture_rect_region(tex_window, Rect2(x + c, y, w - c * 2.0, c), Rect2(96 + c, 0, 96 - c * 2.0, c))
		draw_texture_rect_region(tex_window, Rect2(x + c, y + h - c, w - c * 2.0, c), Rect2(96 + c, 96 - c, 96 - c * 2.0, c))
	if h > c * 2.0:
		draw_texture_rect_region(tex_window, Rect2(x, y + c, c, h - c * 2.0), Rect2(96, c, c, 96 - c * 2.0))
		draw_texture_rect_region(tex_window, Rect2(x + w - c, y + c, c, h - c * 2.0), Rect2(96 + 96 - c, c, c, 96 - c * 2.0))


func _draw_rmmv_cursor(rect: Rect2) -> void:
	if tex_window == null:
		return
	var alpha := 0.68 + 0.32 * sin(ui_time * 6.2)
	var col := Color(1, 1, 1, alpha)
	var c := 12.0
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y

	draw_texture_rect_region(tex_window, Rect2(x + c, y + c, maxf(0, w - c * 2), maxf(0, h - c * 2)), Rect2(96 + c, 96 + c, 48 - c * 2, 48 - c * 2), col)
	draw_texture_rect_region(tex_window, Rect2(x, y, c, c), Rect2(96, 96, c, c), col)
	draw_texture_rect_region(tex_window, Rect2(x + w - c, y, c, c), Rect2(96 + 48 - c, 96, c, c), col)
	draw_texture_rect_region(tex_window, Rect2(x, y + h - c, c, c), Rect2(96, 96 + 48 - c, c, c), col)
	draw_texture_rect_region(tex_window, Rect2(x + w - c, y + h - c, c, c), Rect2(96 + 48 - c, 96 + 48 - c, c, c), col)
	draw_texture_rect_region(tex_window, Rect2(x + c, y, maxf(0, w - c * 2), c), Rect2(96 + c, 96, 48 - c * 2, c), col)
	draw_texture_rect_region(tex_window, Rect2(x + c, y + h - c, maxf(0, w - c * 2), c), Rect2(96 + c, 96 + 48 - c, 48 - c * 2, c), col)
	draw_texture_rect_region(tex_window, Rect2(x, y + c, c, maxf(0, h - c * 2)), Rect2(96, 96 + c, c, 48 - c * 2), col)
	draw_texture_rect_region(tex_window, Rect2(x + w - c, y + c, c, maxf(0, h - c * 2)), Rect2(96 + 48 - c, 96 + c, c, 48 - c * 2), col)


func _draw_rmmv_pause_sign(pos: Vector2) -> void:
	if tex_window == null:
		return
	var frame := int(ui_time * 6.0) % 4
	var sx := 144.0 + float(frame % 2) * 24.0
	var sy := 96.0 + float(frame / 2) * 24.0
	draw_texture_rect_region(tex_window, Rect2(pos, Vector2(24, 24)), Rect2(sx, sy, 24, 24))


func _draw_rmmv_icon(icon_index: int, pos: Vector2) -> void:
	if tex_icons == null:
		return
	var sx := float(icon_index % 16) * 32.0
	var sy := float(icon_index / 16) * 32.0
	draw_texture_rect_region(tex_icons, Rect2(pos, Vector2(32, 32)), Rect2(sx, sy, 32, 32))


func _draw_rmmv_face(face_index: int, pos: Vector2) -> void:
	if tex_faces == null:
		return
	var sx := float(face_index % 4) * 144.0
	var sy := float(face_index / 4) * 144.0
	draw_texture_rect_region(tex_faces, Rect2(pos, Vector2(144, 144)), Rect2(sx, sy, 144, 144))


func _draw_tile(tex: Texture2D, dst_col: int, dst_row: int, src_col: int, src_row: int, w_tiles: int = 1, h_tiles: int = 1) -> void:
	if tex == null:
		return
	var dst := Rect2(dst_col * TILE, dst_row * TILE, w_tiles * TILE, h_tiles * TILE)
	var src := Rect2(src_col * TILE, src_row * TILE, w_tiles * TILE, h_tiles * TILE)
	draw_texture_rect_region(tex, dst, src)


func _draw_rmmv_text(pos: Vector2, text: String, size: int = 22, color: Color = Color.WHITE) -> void:
	var f := game_font if game_font != null else ThemeDB.fallback_font
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.55))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_rmmv_gauge(rect: Rect2, ratio: float, c1: Color, c2: Color, label: String, current_val: int, max_val: int) -> void:
	var bar_y := rect.position.y + 22
	var bar_r := Rect2(rect.position.x, bar_y, rect.size.x, 6)
	draw_rect(bar_r, Color(0.12, 0.14, 0.20, 0.85), true)
	var fill_w := maxf(0.0, bar_r.size.x * clampf(ratio, 0.0, 1.0))
	if fill_w > 0.0:
		draw_rect(Rect2(bar_r.position.x, bar_r.position.y, fill_w * 0.5, bar_r.size.y), c1, true)
		draw_rect(Rect2(bar_r.position.x + fill_w * 0.5, bar_r.position.y, fill_w * 0.5, bar_r.size.y), c2, true)
	_draw_rmmv_text(Vector2(rect.position.x, rect.position.y + 18), label, 20, Color(0.52, 0.78, 1.0))
	_draw_rmmv_text(Vector2(rect.end.x - 98, rect.position.y + 18), "%d / %d" % [current_val, max_val], 20, Color.WHITE)


func _draw() -> void:
	_draw_rmmv_room()

	if state in [State.DIALOG, State.CHOICE] or closing_dialog:
		_draw_rmmv_dialog()

	if state == State.MENU:
		_draw_rmmv_menu()


func _draw_rmmv_room() -> void:
	draw_rect(Rect2(0, 0, 816, 624), Color(0, 0, 0, 1), true)

	# 1. ПОТОЛОЧНЫЙ СРЕЗ СТЕН (Wall Top из Inside_A4.png: коричневая деревянная крыша стен cols 6..7, rows 6..7)
	# Окружает комнату по периметру (cols 1..15, rows 0..11)
	for r in range(1, 12):
		for c in range(1, 16):
			if c == 1 or c == 15 or r == 1 or r == 11:
				_draw_tile(tex_a4, c, r, 6, 6)

	# 2. ДВУХКЛЕТОЧНАЯ ЛИЦЕВАЯ СТЕНА ВВЕРХУ (Wall Face из Inside_A4.png: деревянная панель с молдингом col 4, rows 8..9)
	for c in range(2, 15):
		_draw_tile(tex_a4, c, 2, 4, 8)
		_draw_tile(tex_a4, c, 3, 4, 9)

	# 3. ДЕРЕВЯННЫЙ ПАРКЕТ ПОЛА (Inside_A5.png: тёплый паркет col 2, row 2)
	for r in range(4, 11):
		for c in range(2, 15):
			_draw_tile(tex_a5, c, r, 2, 2)

	# 4. УЗОРЧАТЫЙ КРАСНЫЙ КОВЁР В ЦЕНТРЕ (Inside_A5.png: col 1, row 12 с краями col 0 и col 3)
	for r in range(6, 10):
		_draw_tile(tex_a5, 5, r, 0, 12)
		for c in range(6, 11):
			_draw_tile(tex_a5, c, r, 1, 12)
		_draw_tile(tex_a5, 11, r, 3, 12)

	# 5. ФИРМЕННАЯ ТЕНЬ СТЕНЫ СЛЕВА (24px = полклетки, которая в RPG Maker MV даёт объём комнате!)
	draw_rect(Rect2(2 * TILE, 4 * TILE, 24, 7 * TILE), Color(0, 0, 0, 0.35), true)

	# 6. НАСТЕННЫЙ ДЕКОР ИЗ INSIDE_B.PNG:
	# Окна с портьерами (cols 1, 3, rows 4..5)
	_draw_tile(tex_b, 2, 2, 1, 4, 1, 2)
	_draw_tile(tex_b, 14, 2, 1, 4, 1, 2)
	# Старинные часы (col 8, rows 4..5)
	_draw_tile(tex_b, 6, 2, 8, 4, 1, 2)

	# 7. МЕБЕЛЬ У ВЕРХНЕЙ СТЕНЫ (rows 3..4):
	# Книжные шкафы с томами (Inside_B: cols 4..7, rows 8..9)
	_draw_tile(tex_b, 3, 3, 4, 8, 4, 2)
	# Каменный камин (Inside_B: cols 8..10, rows 0..2)
	_draw_tile(tex_b, 7, 2, 8, 0, 3, 3)
	# Чёрное кабинетное пианино (Inside_B: cols 5..6, rows 12..13)
	_draw_tile(tex_b, 10, 3, 5, 12, 2, 2)
	# Духовой орган (Inside_B: cols 5..6, rows 14..15)
	_draw_tile(tex_b, 12, 3, 5, 14, 2, 2)

	# 8. МЕБЕЛЬ В КОМНАТЕ:
	# Стул у стола (Inside_B: col 8, rows 6..7)
	_draw_tile(tex_b, 4, 5, 8, 6, 1, 2)
	# Деревянный стол с раскрытой нотной книгой и пером (Inside_B + Inside_C)
	_draw_tile(tex_b, 4, 7, 4, 12, 1, 1)
	_draw_tile(tex_b, 5, 7, 4, 12, 1, 1)
	_draw_tile(tex_c, 4, 7, 4, 7, 1, 1)
	_draw_tile(tex_c, 5, 7, 1, 9, 1, 1)
	# Кровать справа (Inside_B: cols 1..2, rows 10..11)
	_draw_tile(tex_b, 12, 7, 1, 10, 2, 2)

	# 9. ПЕРСОНАЖ ИЗ ACTOR1.PNG (48x48, смещён на 6px вверх от нижнего края клетки точно как в Sprite_Character RMMV!)
	if tex_actor != null:
		var src_col := step_pattern
		var src_row := 4 + player_dir
		var dst_rect := Rect2(roundf(pixel_pos.x), roundf(pixel_pos.y) - 6.0, 48, 48)
		draw_texture_rect_region(tex_actor, dst_rect, Rect2(src_col * 48, src_row * 48, 48, 48))


func _draw_rmmv_dialog() -> void:
	# В RPG Maker MV Window_Message внизу имеет ровно (0, 444, 816, 180)
	var msg_rect := Rect2(0, 444, 816, 180)
	_draw_rmmv_window(msg_rect, window_openness)

	if window_openness < 0.92:
		return

	# Портрет 144x144 слева (18, 462)
	_draw_rmmv_face(current_face_index, Vector2(18, 462))

	# Текст (шрифт mplus-1m-regular.ttf, размер 22, межстрочный интервал 36px как lineHeight() в RMMV)
	var f := game_font if game_font != null else ThemeDB.fallback_font
	var shown := current_line.substr(0, int(visible_chars))
	draw_multiline_string_outline(f, Vector2(186, 492), shown, HORIZONTAL_ALIGNMENT_LEFT, 606, 22, -1, 4, Color(0, 0, 0, 0.6))
	draw_multiline_string(f, Vector2(186, 492), shown, HORIZONTAL_ALIGNMENT_LEFT, 606, 22, -1, Color.WHITE)

	if int(visible_chars) >= current_line.length() and state == State.DIALOG:
		_draw_rmmv_pause_sign(Vector2(396, 596))

	if state == State.CHOICE:
		var row_h := 36.0
		var ch_h := choices.size() * row_h + 36.0
		var ch_w := 440.0
		var ch_rect := Rect2(816.0 - ch_w, 444.0 - ch_h, ch_w, ch_h)
		_draw_rmmv_window(ch_rect, 1.0)
		for i in range(choices.size()):
			var item_r := Rect2(ch_rect.position.x + 18, ch_rect.position.y + 18 + i * row_h, ch_w - 36, row_h)
			if i == choice_index:
				_draw_rmmv_cursor(item_r)
			_draw_rmmv_text(Vector2(item_r.position.x + 10, item_r.position.y + 26), choices[i], 21, Color.WHITE)


func _draw_rmmv_menu() -> void:
	# Притемнение фона карты как в Scene_MenuBase
	draw_rect(Rect2(0, 0, 816, 624), Color(0, 0, 0, 0.45), true)

	# 1. Window_MenuCommand (0, 0, 240, 288)
	_draw_rmmv_window(Rect2(0, 0, 240, 288))
	for i in range(menu_items.size()):
		var r := Rect2(18, 18 + i * 36, 204, 36)
		if i == menu_index:
			_draw_rmmv_cursor(r)
		_draw_rmmv_text(Vector2(r.position.x + 10, r.position.y + 26), menu_items[i], 22, Color.WHITE)

	# 2. Window_Gold (0, 552, 240, 72)
	_draw_rmmv_window(Rect2(0, 552, 240, 72))
	_draw_rmmv_text(Vector2(104, 596), "5 027", 22, Color.WHITE)
	_draw_rmmv_text(Vector2(198, 596), "G", 22, Color(0.52, 0.78, 1.0))

	# 3. Window_MenuStatus (240, 0, 576, 624)
	_draw_rmmv_window(Rect2(240, 0, 576, 624))

	var actor_card := Rect2(258, 18, 540, 154)
	_draw_rmmv_cursor(actor_card)
	_draw_rmmv_face(4, Vector2(264, 23))

	_draw_rmmv_text(Vector2(426, 52), "Алексей", 22, Color.WHITE)
	_draw_rmmv_text(Vector2(576, 52), "Композитор", 22, Color.WHITE)
	_draw_rmmv_text(Vector2(426, 92), "Ур.", 20, Color(0.52, 0.78, 1.0))
	_draw_rmmv_text(Vector2(474, 92), "19", 22, Color.WHITE)

	_draw_rmmv_gauge(Rect2(552, 64, 226, 32), 1.0, Color(0.88, 0.38, 0.20), Color(0.98, 0.68, 0.32), "HP", 450, 450)
	_draw_rmmv_gauge(Rect2(552, 98, 226, 32), 0.90, Color(0.22, 0.48, 0.92), Color(0.45, 0.78, 1.0), "MP", 180, 200)
	_draw_rmmv_gauge(Rect2(552, 132, 226, 32), 0.85, Color(0.18, 0.72, 0.36), Color(0.48, 0.96, 0.62), "TP", 85, 100)
