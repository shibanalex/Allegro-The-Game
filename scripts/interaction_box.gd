extends Control
class_name InteractionBox

signal closed

# Concept 1 palette: Smoked bottom gradient (no box) + breaking-the-frame cut-in artwork + single crisp hairline
const COL_GRAD_TOP := Color(0.020, 0.024, 0.039, 0.0)
const COL_GRAD_MID := Color(0.020, 0.027, 0.043, 0.74)
const COL_GRAD_BOT := Color(0.016, 0.020, 0.031, 0.95)
const COL_FRAME_BG := Color(0.035, 0.043, 0.063, 1.0)
const COL_FRAME_RIM := Color(0.847, 0.886, 0.933, 0.92)     # #d8e2ee Crisp 1px pale grey-blue frame rim
const COL_HAIRLINE := Color(0.647, 0.714, 0.800, 0.58)      # #a5b6cc Thin horizontal divider thread
const COL_TITLE := Color(0.647, 0.714, 0.800, 1.0)          # #a5b6cc Cool grey-blue object header
const COL_TEXT := Color(0.933, 0.949, 0.973, 1.0)           # #eef2f8 Crisp pale text
const COL_TEXT_SHADOW := Color(0.012, 0.016, 0.027, 0.94)

var font: Font
var se_cursor: AudioStream
var _grad_tex: GradientTexture2D

var active: bool = false
var closing: bool = false
var openness: float = 0.0
var ui_time: float = 0.0

var current_title: String = ""
var pages: PackedStringArray = []
var page_idx: int = 0
var char_progress: float = 0.0
var typing_speed: float = 34.0

var custom_tex: Texture2D = null
var custom_crop: Rect2 = Rect2()
var fallback_tex: Texture2D = null
var fallback_region: Rect2 = Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = load("res://assets/rmmv/fonts/mplus-1m-regular.ttf")
	if ResourceLoader.exists("res://assets/rmmv/audio/se/Cursor1.ogg"):
		se_cursor = load("res://assets/rmmv/audio/se/Cursor1.ogg")

	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	g.colors = PackedColorArray([COL_GRAD_TOP, COL_GRAD_MID, COL_GRAD_BOT])
	_grad_tex = GradientTexture2D.new()
	_grad_tex.gradient = g
	_grad_tex.width = 4
	_grad_tex.height = 128
	_grad_tex.fill_from = Vector2(0.0, 0.0)
	_grad_tex.fill_to = Vector2(0.0, 1.0)


func is_open() -> bool:
	return active or openness > 0.01


func open_interaction(
	title: String,
	text_pages: PackedStringArray,
	custom_image_path: String = "",
	atlas_tex: Texture2D = null,
	atlas_region: Rect2 = Rect2(),
	art_crop: Rect2 = Rect2()
) -> void:
	current_title = title
	pages = text_pages if text_pages.size() > 0 else PackedStringArray([""])
	page_idx = 0
	char_progress = 0.0
	active = true
	closing = false

	custom_tex = null
	custom_crop = art_crop
	if custom_image_path != "" and ResourceLoader.exists(custom_image_path):
		custom_tex = load(custom_image_path) as Texture2D
	fallback_tex = atlas_tex
	fallback_region = atlas_region

	_play_tick()
	queue_redraw()


func advance_or_close() -> void:
	if not active or closing:
		return

	var full_page := pages[page_idx] if page_idx < pages.size() else ""
	if int(char_progress) < full_page.length():
		char_progress = float(full_page.length())
		queue_redraw()
		return

	_play_tick()
	if page_idx + 1 < pages.size():
		page_idx += 1
		char_progress = 0.0
	else:
		closing = true
		active = false


func _play_tick() -> void:
	if se_cursor != null:
		var sm := get_node_or_null("/root/SoundManager")
		if sm != null:
			sm.call("play_ui_sound", se_cursor, "MenuUI")


func _process(delta: float) -> void:
	ui_time += delta
	if active and not closing:
		openness = move_toward(openness, 1.0, delta * 6.5)
		if openness > 0.45 and page_idx < pages.size():
			var target_len := float(pages[page_idx].length())
			if char_progress < target_len:
				char_progress = minf(target_len, char_progress + delta * typing_speed)
		queue_redraw()
	elif closing or openness > 0.001:
		openness = move_toward(openness, 0.0, delta * 7.5)
		queue_redraw()
		if openness <= 0.001:
			openness = 0.0
			closing = false
			closed.emit()


func _draw() -> void:
	if openness <= 0.01:
		return

	var sz := get_rect().size
	var ease_a := 1.0 - pow(1.0 - openness, 3.0)
	var slide_y := roundf((1.0 - ease_a) * 14.0)

	# 1. Boxless bottom smoked gradient veil spanning the full screen width
	var grad_h := 228.0
	if _grad_tex != null:
		draw_texture_rect(
			_grad_tex,
			Rect2(0.0, sz.y - grad_h, sz.x, grad_h),
			false,
			Color(1.0, 1.0, 1.0, ease_a)
		)

	# Content composition width centered horizontally at the bottom
	var comp_w := minf(880.0, sz.x - 80.0)
	var comp_x := roundf((sz.x - comp_w) * 0.5)

	var has_picture := (custom_tex != null) or (fallback_tex != null and fallback_region.size.x > 0.0)
	var fw := 184.0
	var fh := 172.0
	var fx := comp_x
	var fy := roundf(sz.y - 36.0 - fh + slide_y)
	var tx0 := comp_x

	# 2. Large overlapping cut-in artwork frame on the left that breaks ABOVE the text hairline
	if has_picture:
		var frame_rect := Rect2(fx, fy, fw, fh)
		# Soft deep drop shadow behind cut-in frame
		draw_rect(Rect2(fx + 6.0, fy + 8.0, fw, fh), Color(0.01, 0.015, 0.025, 0.72 * ease_a))
		# Dark slate backing
		var bg_col := COL_FRAME_BG
		bg_col.a = ease_a
		draw_rect(frame_rect, bg_col)

		if custom_tex != null:
			var src_rect := custom_crop
			if src_rect.size.x <= 0.0 or src_rect.size.y <= 0.0:
				var tw := float(custom_tex.get_width())
				var th := float(custom_tex.get_height())
				var scale_c := maxf(fw / maxf(1.0, tw), fh / maxf(1.0, th))
				var sw := fw / scale_c
				var sh := fh / scale_c
				src_rect = Rect2((tw - sw) * 0.5, (th - sh) * 0.5, sw, sh)
			draw_texture_rect_region(custom_tex, frame_rect, src_rect, Color(1.0, 1.0, 1.0, ease_a))
		elif fallback_tex != null:
			var rw := fallback_region.size.x
			var rh := fallback_region.size.y
			var sc := minf((fw - 28.0) / maxf(1.0, rw), (fh - 28.0) / maxf(1.0, rh))
			var dw := roundf(rw * sc)
			var dh := roundf(rh * sc)
			var dx := fx + roundf((fw - dw) * 0.5)
			var dy := fy + roundf((fh - dh) * 0.5)
			draw_texture_rect_region(fallback_tex, Rect2(dx, dy, dw, dh), fallback_region, Color(1.0, 1.0, 1.0, ease_a))

		# Crisp 1px pale grey-blue border around the cut-in frame
		var rim_col := COL_FRAME_RIM
		rim_col.a *= ease_a
		draw_rect(frame_rect, rim_col, false, 1.0)
		tx0 = fx + fw + 28.0

	# 3. Single thin horizontal hairline + Object Title & unboxed text to the right of the cut-in frame
	var line_y := roundf(sz.y - 126.0 + slide_y)
	var text_w := (comp_x + comp_w) - tx0

	var h_col := COL_HAIRLINE
	h_col.a *= ease_a
	draw_line(Vector2(tx0, line_y), Vector2(comp_x + comp_w, line_y), h_col, 1.0)

	if font != null:
		var t_col := COL_TITLE
		t_col.a *= ease_a
		var sh_col := COL_TEXT_SHADOW
		sh_col.a *= ease_a
		draw_string(font, Vector2(tx0 + 1.0, line_y - 9.0), current_title, HORIZONTAL_ALIGNMENT_LEFT, text_w, 16, sh_col)
		draw_string(font, Vector2(tx0, line_y - 10.0), current_title, HORIZONTAL_ALIGNMENT_LEFT, text_w, 16, t_col)

		if page_idx < pages.size():
			var full_page := pages[page_idx]
			var shown_len := clampi(int(char_progress), 0, full_page.length())
			var visible_str := full_page.substr(0, shown_len)
			var sub_lines := visible_str.split("\n")
			var row_y := line_y + 32.0
			var body_col := COL_TEXT
			body_col.a *= ease_a
			for ln in sub_lines:
				draw_string(font, Vector2(tx0 + 1.5, row_y + 1.5), ln, HORIZONTAL_ALIGNMENT_LEFT, text_w, 22, sh_col)
				draw_string(font, Vector2(tx0, row_y), ln, HORIZONTAL_ALIGNMENT_LEFT, text_w, 22, body_col)
				row_y += 30.0

			if shown_len >= full_page.length():
				var pulse := (0.35 + 0.55 * (0.5 + 0.5 * sin(ui_time * 4.4))) * ease_a
				var p_col := COL_TITLE
				p_col.a = pulse
				draw_string(font, Vector2(comp_x + comp_w - 18.0, sz.y - 34.0 + slide_y), "▼", HORIZONTAL_ALIGNMENT_LEFT, 20.0, 13, p_col)
