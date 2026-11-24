extends Control

const GAME_SCENE_PATH := "res://house_modular.tscn"
const FILLER_THEME_PATH := "res://assets/audio/Filler theme.wav"
const BED_TEX_PATH := "res://assets/title/bed_intro_bg.png"

var font: Font
var bed_tex: Texture2D
var se_cursor: AudioStream

# Cutscene lines shown on the bottom black bar (easy to extend with more lines)
var lines: PackedStringArray = [
	"7 утра."
]
var line_idx: int = 0
var char_progress: float = 0.0
var typing_speed: float = 22.0
var hold_timer: float = 0.0
var ui_time: float = 0.0

var fade_alpha: float = 1.0
var transitioning: bool = false
var _preloaded_scene: PackedScene = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = load("res://assets/rmmv/fonts/mplus-1m-regular.ttf")
	bed_tex = load(BED_TEX_PATH)
	if ResourceLoader.exists("res://assets/rmmv/audio/se/Cursor1.ogg"):
		se_cursor = load("res://assets/rmmv/audio/se/Cursor1.ogg")

	# Preload the main house scene and music while the player views the opening bed scene
	ResourceLoader.load_threaded_request(GAME_SCENE_PATH)
	ResourceLoader.load_threaded_request(FILLER_THEME_PATH)

	var tw := create_tween()
	tw.tween_property(self, "fade_alpha", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	ui_time += delta

	if _preloaded_scene == null and ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH) == ResourceLoader.THREAD_LOAD_LOADED:
		_preloaded_scene = ResourceLoader.load_threaded_get(GAME_SCENE_PATH) as PackedScene

	if not transitioning:
		if fade_alpha < 0.35:
			var current_line := lines[line_idx] if line_idx < lines.size() else ""
			if char_progress < float(current_line.length()):
				char_progress = minf(float(current_line.length()), char_progress + delta * typing_speed)
			else:
				hold_timer += delta
	else:
		if fade_alpha >= 0.99:
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
	if transitioning:
		return

	var advance_pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z, KEY_ESCAPE]:
			advance_pressed = true
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		advance_pressed = true

	if advance_pressed:
		_advance()


func _advance() -> void:
	var current_line := lines[line_idx] if line_idx < lines.size() else ""
	if int(char_progress) < current_line.length():
		char_progress = float(current_line.length())
		queue_redraw()
		return

	if se_cursor != null:
		var sm := get_node_or_null("/root/SoundManager")
		if sm != null:
			sm.call("play_ui_sound", se_cursor, "MenuUI")

	if line_idx + 1 < lines.size():
		line_idx += 1
		char_progress = 0.0
		hold_timer = 0.0
	else:
		transitioning = true
		var tw := create_tween()
		tw.tween_property(self, "fade_alpha", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _draw() -> void:
	var sz := get_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return

	# Solid pitch-black background
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.0, 0.0, 0.0, 1.0))

	# Proportions matching the reference visual novel frame:
	# Top letterbox bar (~9.5%), middle dithered bedroom frame (~64.5%), bottom dialogue letterbox bar (~26%)
	var top_bar_h := roundf(sz.y * 0.095)
	var bot_bar_y := roundf(sz.y * 0.740)
	var mid_h := bot_bar_y - top_bar_h

	# Draw the 320x180 4-tone grey-blue Bayer-dithered bed photo inside the middle band, preserving crisp integer/nearest pixels
	if bed_tex != null and mid_h > 0.0:
		var tex_w := float(bed_tex.get_width())
		var tex_h := float(bed_tex.get_height())
		var scale_cover := maxf(sz.x / tex_w, mid_h / tex_h)
		var src_w := sz.x / scale_cover
		var src_h := mid_h / scale_cover
		var src_x := (tex_w - src_w) * 0.5
		var src_y := (tex_h - src_h) * 0.45
		draw_texture_rect_region(
			bed_tex,
			Rect2(0.0, top_bar_h, sz.x, mid_h),
			Rect2(src_x, src_y, src_w, src_h)
		)

	# Re-enforce crisp top & bottom black bars and 2px pale grey-blue divider lines (#d8e2ee)
	var line_col := Color(0.847, 0.886, 0.933, 1.0)
	draw_rect(Rect2(0.0, 0.0, sz.x, top_bar_h), Color(0.0, 0.0, 0.0, 1.0))
	draw_rect(Rect2(0.0, bot_bar_y, sz.x, sz.y - bot_bar_y), Color(0.0, 0.0, 0.0, 1.0))
	draw_rect(Rect2(0.0, top_bar_h - 2.0, sz.x, 2.0), line_col)
	draw_rect(Rect2(0.0, bot_bar_y, sz.x, 2.0), line_col)

	# Draw "7 утра." centered in the bottom black bar
	if font != null and line_idx < lines.size():
		var full_text := lines[line_idx]
		var shown_len := clampi(int(char_progress), 0, full_text.length())
		var visible_text := full_text.substr(0, shown_len)
		var font_size := 28
		var text_y := bot_bar_y + (sz.y - bot_bar_y) * 0.48
		draw_string(
			font,
			Vector2(0.0, text_y),
			visible_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			sz.x,
			font_size,
			Color(0.93, 0.95, 0.98, 1.0)
		)

		# Subtle pulsing continue prompt when line finishes typing
		if shown_len >= full_text.length():
			var pulse := 0.35 + 0.45 * (0.5 + 0.5 * sin(ui_time * 4.2))
			draw_string(
				font,
				Vector2(0.0, sz.y - 22.0),
				"▼",
				HORIZONTAL_ALIGNMENT_CENTER,
				sz.x,
				14,
				Color(0.66, 0.75, 0.86, pulse)
			)

	# Fade overlay
	if fade_alpha > 0.01:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.0, 0.0, 0.0, clampf(fade_alpha, 0.0, 1.0)))
