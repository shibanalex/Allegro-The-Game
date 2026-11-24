extends Control

const GAME_SCENE_PATH := "res://intro_cutscene.tscn"
const FILLER_THEME_PATH := "res://assets/audio/Filler theme.wav"

var font: Font
var tex_window: Texture2D
var se_cursor: AudioStream
var se_decision: AudioStream

var items: PackedStringArray = ["Начать игру", "Выход"]
var selected_idx: int = 0
var ui_time: float = 0.0
var starting: bool = false
var fade_alpha: float = 1.0  # Starts black, quickly reveals title
var _preloaded_scene: PackedScene = null
var _preloaded_theme: AudioStream = null

@onready var menu_snow: CPUParticles2D = get_node_or_null("MenuSnow")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = load("res://assets/rmmv/fonts/mplus-1m-regular.ttf")
	tex_window = load("res://assets/rmmv/img/system/Window.png")
	se_cursor = load("res://assets/rmmv/audio/se/Cursor1.ogg")
	se_decision = load("res://assets/rmmv/audio/se/Decision1.ogg")

	# Start background loading of the village house scene + music immediately while player is in menu
	ResourceLoader.load_threaded_request(GAME_SCENE_PATH)
	ResourceLoader.load_threaded_request(FILLER_THEME_PATH)

	var tw := create_tween()
	tw.tween_property(self, "fade_alpha", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	ui_time += delta
	if menu_snow != null:
		menu_snow.position.x = get_rect().size.x * 0.5

	if _preloaded_scene == null and ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH) == ResourceLoader.THREAD_LOAD_LOADED:
		_preloaded_scene = ResourceLoader.load_threaded_get(GAME_SCENE_PATH) as PackedScene
	if _preloaded_theme == null and ResourceLoader.load_threaded_get_status(FILLER_THEME_PATH) == ResourceLoader.THREAD_LOAD_LOADED:
		_preloaded_theme = ResourceLoader.load_threaded_get(FILLER_THEME_PATH) as AudioStream

	if starting and fade_alpha >= 0.99:
		var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH)
		if _preloaded_scene != null:
			if ResourceLoader.load_threaded_get_status(FILLER_THEME_PATH) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				queue_redraw()
				return
			get_tree().change_scene_to_packed(_preloaded_scene)
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			queue_redraw()
			return
		else:
			get_tree().change_scene_to_file(GAME_SCENE_PATH)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if starting:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key in [KEY_UP, KEY_W]:
			_move_selection(-1)
		elif key in [KEY_DOWN, KEY_S]:
			_move_selection(1)
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z]:
			_activate_selected()
		elif key == KEY_ESCAPE:
			_play_ui(se_cursor)
			get_tree().quit()
	elif event is InputEventMouseMotion:
		var idx := _item_at_pos((event as InputEventMouseMotion).position)
		if idx != -1 and idx != selected_idx:
			selected_idx = idx
			_play_ui(se_cursor)
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var idx := _item_at_pos((event as InputEventMouseButton).position)
		if idx != -1:
			selected_idx = idx
			_activate_selected()


func _move_selection(step: int) -> void:
	selected_idx = (selected_idx + step + items.size()) % items.size()
	_play_ui(se_cursor)


func _activate_selected() -> void:
	_play_ui(se_decision)
	if selected_idx == 0:
		starting = true
		var tw := create_tween()
		tw.tween_property(self, "fade_alpha", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		get_tree().quit()


func _play_ui(stream: AudioStream) -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm != null and stream != null:
		sm.call("play_ui_sound", stream, "MenuUI")


func _menu_box_rect() -> Rect2:
	var sz := get_rect().size
	var w := 264.0
	var h := 112.0
	return Rect2((sz.x - w) * 0.5, sz.y * 0.60, w, h)


func _item_rect(i: int) -> Rect2:
	var box := _menu_box_rect()
	var row_h := 38.0
	var top_pad := 18.0
	return Rect2(box.position.x + 16.0, box.position.y + top_pad + float(i) * row_h, box.size.x - 32.0, row_h)


func _item_at_pos(pos: Vector2) -> int:
	for i in range(items.size()):
		if _item_rect(i).has_point(pos):
			return i
	return -1


func _draw() -> void:
	var sz := get_rect().size

	# Subtle title typography in the upper third with rich shadow for effortless legibility
	if font != null:
		var title := "Allegro"
		var title_size := 64
		var title_y := sz.y * 0.34
		var shadow_col := Color(0.02, 0.024, 0.04, 0.92)
		for off in [Vector2(-1.5, 1.5), Vector2(2.0, 2.0), Vector2(3.5, 4.5)]:
			draw_string(font, Vector2(off.x, title_y + off.y), title, HORIZONTAL_ALIGNMENT_CENTER, sz.x, title_size, shadow_col)
		draw_string(font, Vector2(0.0, title_y), title, HORIZONTAL_ALIGNMENT_CENTER, sz.x, title_size, Color(0.92, 0.94, 0.97, 1.0))

	# Classic RPG Maker command window
	var box := _menu_box_rect()
	_draw_rmmv_window(box)
	_draw_rmmv_cursor(_item_rect(selected_idx))

	if font != null:
		for i in range(items.size()):
			var ir := _item_rect(i)
			var text_col := Color(0.95, 0.96, 0.98, 1.0) if i == selected_idx else Color(0.68, 0.72, 0.78, 0.92)
			var baseline_y := ir.position.y + ir.size.y * 0.68
			draw_string(font, Vector2(ir.position.x + 1.5, baseline_y + 1.5), items[i], HORIZONTAL_ALIGNMENT_CENTER, ir.size.x, 22, Color(0.04, 0.05, 0.08, 0.9))
			draw_string(font, Vector2(ir.position.x, baseline_y), items[i], HORIZONTAL_ALIGNMENT_CENTER, ir.size.x, 22, text_col)

	# Black fade / loading transition
	if fade_alpha > 0.01:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.025, 0.025, 0.035, clampf(fade_alpha, 0.0, 1.0)))
		if starting and fade_alpha > 0.85 and font != null:
			var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				draw_string(font, Vector2(0.0, sz.y - 42.0), "Загрузка...", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 18, Color(0.65, 0.70, 0.78, 0.8))


func _draw_rmmv_window(rect: Rect2) -> void:
	if tex_window == null:
		return
	var back_rect := rect.grow(-4.0)
	if back_rect.size.x > 0 and back_rect.size.y > 0:
		draw_texture_rect_region(tex_window, back_rect, Rect2(0, 0, 96, 96), Color(0.18, 0.22, 0.30, 0.88))
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
				draw_texture_rect_region(tex_window, Rect2(tx, ty, tw, th), Rect2(0, 96, tw, th), Color(1, 1, 1, 0.28))
				tx += 96.0
			ty += 96.0

	var c := minf(24.0, rect.size.y * 0.5)
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
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
	var alpha := 0.65 + 0.35 * sin(ui_time * 5.8)
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
