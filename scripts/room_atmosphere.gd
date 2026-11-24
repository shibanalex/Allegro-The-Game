extends Node2D

const FILLER_THEME_PATH := "res://assets/audio/Filler theme.wav"
const SWITCH_SE_PATH := "res://assets/rmmv/audio/se/Cursor1.ogg"
const INTERACTION_BOX_SCRIPT := preload("res://scripts/interaction_box.gd")
const FURN_ATLAS_PATH := "res://assets/tilesets/house_furniture_atlas.png"

@onready var window_light: PointLight2D = get_node_or_null("WindowNightLight")
@onready var morning_window_light: PointLight2D = get_node_or_null("WindowMorningLight")
@onready var window_god_rays: ColorRect = get_node_or_null("WindowGodRays")
@onready var hallway_warm_light: PointLight2D = get_node_or_null("HallwayWarmLight")
@onready var kitchen_light: PointLight2D = get_node_or_null("KitchenLight")
@onready var entry_light: PointLight2D = get_node_or_null("EntryLight")
@onready var piano_light: PointLight2D = get_node_or_null("PianoScoreLight")
@onready var simple_desk_node: Node2D = get_node_or_null("YSort/SimpleDesk")
@onready var desk_lamp_light: PointLight2D = _find_first_light([
	"YSort/SimpleDesk/DeskLampLight",
	"YSort/ComposerDesk/DeskLampLight",
])
@onready var desk_lamp_halo: PointLight2D = _find_first_light([
	"YSort/SimpleDesk/DeskLampCoreHalo",
	"YSort/ComposerDesk/DeskLampCoreHalo",
])
@onready var laptop_glow: PointLight2D = get_node_or_null("YSort/ComposerDesk/LaptopScreenGlow")
@onready var simple_laptop_glow: PointLight2D = get_node_or_null("YSort/SimpleDesk/LaptopScreenGlow")
@onready var hero_player: Node2D = get_node_or_null("YSort/Player") as Node2D
@onready var fade_overlay: ColorRect = get_node_or_null("TransitionLayer/FadeOverlay")

var _time: float = 0.0
var desk_lamp_on: bool = true
var _lamp_blend: float = 1.0
var _switch_se: AudioStream = null
var _base_ray_color: Color = Color(0.66, 0.78, 0.90, 0.115)
var _interaction_box: Control = null
var _furn_atlas_tex: Texture2D = null


func _find_first_light(paths: Array[String]) -> PointLight2D:
	for p in paths:
		var n := get_node_or_null(p) as PointLight2D
		if n != null:
			return n
	return null


func _ready() -> void:
	if ResourceLoader.exists(SWITCH_SE_PATH):
		_switch_se = load(SWITCH_SE_PATH) as AudioStream
	if ResourceLoader.exists(FURN_ATLAS_PATH):
		_furn_atlas_tex = load(FURN_ATLAS_PATH) as Texture2D

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "InteractionLayer"
	ui_layer.layer = 9
	add_child(ui_layer)
	_interaction_box = INTERACTION_BOX_SCRIPT.new()
	_interaction_box.name = "InteractionBox"
	_interaction_box.connect("closed", Callable(self, "_on_interaction_closed"))
	ui_layer.add_child(_interaction_box)

	if window_god_rays != null and window_god_rays.material is ShaderMaterial:
		var c = (window_god_rays.material as ShaderMaterial).get_shader_parameter("ray_color")
		if c is Color:
			_base_ray_color = c

	if morning_window_light != null and ResourceLoader.exists(FILLER_THEME_PATH):
		var filler_stream := load(FILLER_THEME_PATH) as AudioStream
		if filler_stream is AudioStreamWAV:
			var wav := filler_stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			if wav.loop_end <= 0:
				wav.loop_end = int(round(wav.get_length() * float(wav.mix_rate)))
		var sm: Node = get_node_or_null("/root/SoundManager")
		if filler_stream != null and sm != null:
			if not bool(sm.call("is_music_playing", filler_stream)):
				sm.call("play_music_at_volume", filler_stream, -5.0, 4.0, "Music")

	if fade_overlay != null:
		_run_scene_intro()


func _on_interaction_closed() -> void:
	if hero_player != null:
		hero_player.set("can_move", true)


func _unhandled_input(event: InputEvent) -> void:
	if _interaction_box != null and bool(_interaction_box.call("is_open")):
		if event is InputEventKey and event.pressed and not event.echo:
			var k := (event as InputEventKey).keycode
			if k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z, KEY_ESCAPE]:
				_interaction_box.call("advance_or_close")
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_interaction_box.call("advance_or_close")
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		# Press F near the desk to toggle the warm brass desk lamp dynamically
		if key == KEY_F and simple_desk_node != null and hero_player != null and desk_lamp_light != null:
			if hero_player.global_position.distance_to(simple_desk_node.global_position) <= 64.0:
				desk_lamp_on = not desk_lamp_on
				var sm := get_node_or_null("/root/SoundManager")
				if sm != null and _switch_se != null:
					sm.call("play_ui_sound", _switch_se)
				return

		if key in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z]:
			_try_inspect_nearby()


func _try_inspect_nearby() -> void:
	if hero_player == null or _interaction_box == null:
		return
	var p := hero_player.global_position

	# Interactive props: checks custom image at res://assets/interactions/<id>.png first,
	# falling back to the prop sprite from house_furniture_atlas.png until a custom picture is placed.
	var bed_node := get_node_or_null("YSort/SingleBed") as Node2D
	if bed_node != null and p.distance_to(bed_node.global_position + Vector2(0, -18)) <= 56.0:
		hero_player.set("can_move", false)
		var bed_img := "res://assets/interactions/bed.png" if ResourceLoader.exists("res://assets/interactions/bed.png") else "res://assets/title/bed_intro_bg.png"
		var bed_crop := Rect2() if ResourceLoader.exists("res://assets/interactions/bed.png") else Rect2(56, 6, 196, 174)
		_interaction_box.call(
			"open_interaction",
			"КРОВАТЬ",
			PackedStringArray(["Простыня ещё хранит тепло.\nЛожиться обратно уже нет смысла."]),
			bed_img,
			_furn_atlas_tex,
			Rect2(0, 0, 64, 96),
			bed_crop
		)
		return

	if simple_desk_node != null and p.distance_to(simple_desk_node.global_position) <= 58.0:
		hero_player.set("can_move", false)
		_interaction_box.call(
			"open_interaction",
			"РАБОЧИЙ СТОЛ",
			PackedStringArray(["Черновик трио обрывается на середине такта.\nЛампа гудит едва слышно, согревая пустой лист."]),
			"res://assets/interactions/desk.png",
			_furn_atlas_tex,
			Rect2(64, 0, 96, 64)
		)
		return

	# Winter window on the hero room north wall
	if p.distance_to(Vector2(102, 326)) <= 46.0:
		hero_player.set("can_move", false)
		_interaction_box.call(
			"open_interaction",
			"ОКНО",
			PackedStringArray(["За мутным стеклом медленно оседает утренний снег.\nСемь утра — весь дом ещё спит."]),
			"res://assets/interactions/window.png",
			null,
			Rect2()
		)
		return

	var kwu_node := get_node_or_null("YSort/KitchenWallUnit") as Node2D
	if kwu_node != null and p.distance_to(kwu_node.global_position) <= 64.0:
		hero_player.set("can_move", false)
		_interaction_box.call(
			"open_interaction",
			"КУХНЯ",
			PackedStringArray(["Жестяной чайник на столешнице давно остыл.\nПахнет сухим деревом и вчерашним чаем."]),
			"res://assets/interactions/kitchen_unit.png",
			_furn_atlas_tex,
			Rect2(0, 96, 96, 96)
		)
		return

	var ktbl_node := get_node_or_null("YSort/KitchenTable") as Node2D
	if ktbl_node != null and p.distance_to(ktbl_node.global_position) <= 58.0:
		hero_player.set("can_move", false)
		_interaction_box.call(
			"open_interaction",
			"ОБЕДЕННЫЙ СТОЛ",
			PackedStringArray(["На льняной дорожке стоит глиняный заварник и две чашки."]),
			"res://assets/interactions/kitchen_table.png",
			_furn_atlas_tex,
			Rect2(192, 128, 64, 64)
		)
		return


func _run_scene_intro() -> void:
	if hero_player != null:
		hero_player.set("can_move", false)
	# Wait 2 frames behind black so GPU shaders and lighting compile before revealing the room
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(fade_overlay, "modulate:a", 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_inside_tree():
		return
	# HOOK: будущее место для стартовой катсцены пробуждения перед передачей управления игроку
	if hero_player != null:
		hero_player.set("can_move", true)


func _process(delta: float) -> void:
	_time += delta

	# Smooth tungsten filament warm-up / cool-down when toggled
	var target_blend := 1.0 if desk_lamp_on else 0.0
	_lamp_blend = move_toward(_lamp_blend, target_blend, delta * 5.5)

	# Organic tungsten bulb breathing + subtle rare voltage dip
	var micro_flicker: float = 0.0
	var cycle: float = fmod(_time, 7.8)
	if cycle > 7.25 and cycle < 7.42:
		micro_flicker = -0.09 * sin((cycle - 7.25) / 0.17 * PI)

	var lamp_wave: float = sin(_time * 1.85) * 0.022 + sin(_time * 6.9) * 0.009 + micro_flicker
	if desk_lamp_light:
		var base_desk_e := 0.96 if simple_desk_node != null else 0.78
		desk_lamp_light.energy = maxf(0.0, (base_desk_e + lamp_wave) * _lamp_blend)
		desk_lamp_light.visible = _lamp_blend > 0.01
	if desk_lamp_halo:
		var base_halo_e := 0.28 if simple_desk_node != null else 0.28
		desk_lamp_halo.energy = maxf(0.0, (base_halo_e + lamp_wave * 0.55) * _lamp_blend)
		desk_lamp_halo.visible = _lamp_blend > 0.01

	# Faint reflection on the piano sheet music
	if piano_light:
		piano_light.energy = 0.26 + sin(_time * 1.4 + 0.9) * 0.015

	# Overcast winter cloud drift gently modulating window light + volumetric rays in sync
	var cloud_drift := sin(_time * 0.32) * 0.055 + sin(_time * 0.79 + 1.3) * 0.025
	if window_light:
		window_light.energy = 0.46 + sin(_time * 0.9) * 0.025
	if morning_window_light:
		morning_window_light.energy = 0.98 + cloud_drift
	if window_god_rays != null and window_god_rays.material is ShaderMaterial:
		var ray_col := _base_ray_color
		ray_col.a = clampf(_base_ray_color.a * (1.0 + cloud_drift * 1.4), 0.04, 0.22)
		(window_god_rays.material as ShaderMaterial).set_shader_parameter("ray_color", ray_col)

	# Warm residential sconces in hallway & kitchen with subtle living warmth
	if hallway_warm_light:
		hallway_warm_light.energy = 0.96 + sin(_time * 1.15 + 0.7) * 0.022 + sin(_time * 3.7) * 0.007
	if kitchen_light:
		kitchen_light.energy = 0.90 + sin(_time * 1.05 + 2.1) * 0.020
	if entry_light:
		entry_light.energy = 0.78 + cloud_drift * 0.55

	# Subtle cool laptop screen luminance pulse
	if laptop_glow:
		laptop_glow.energy = 0.36 + sin(_time * 3.1) * 0.02 + sin(_time * 11.0) * 0.01
	if simple_laptop_glow:
		simple_laptop_glow.energy = 0.34 + sin(_time * 2.5) * 0.018 + sin(_time * 9.3) * 0.009
