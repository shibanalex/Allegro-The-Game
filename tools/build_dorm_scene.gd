@tool
extends SceneTree

func _init() -> void:
	var json_text := FileAccess.get_file_as_string("res://assets/tilesets/dorm_test_layout.json")
	var layout: Dictionary = JSON.parse_string(json_text)
	var tiles_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tilesets/dorm_a_tiles.json"))
	var tile_defs: Dictionary = tiles_json["tiles"]

	var tileset: TileSet = load("res://assets/tilesets/dorm_a_tileset.tres")
	var furn_tex: Texture2D = load("res://assets/tilesets/boy_room_furniture.png")
	var rug_tex: Texture2D = load("res://assets/tilesets/piano_trio_rug.png")
	var light_tex: Texture2D = load("res://assets/light_soft.png")
	var mote_tex: Texture2D = load("res://assets/particles/dust_mote.png")
	var hero_tex: Texture2D = load("res://assets/characters/hero_allegro_sheet.png")
	var film_shader: Shader = load("res://assets/shaders/night_film.gdshader")
	var shaft_shader: Shader = load("res://assets/shaders/light_shaft.gdshader")

	var root := Node2D.new()
	root.name = "DormModular"
	root.set_script(load("res://scripts/room_atmosphere.gd"))

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.offset_left = -640.0
	backdrop.offset_top = -480.0
	backdrop.offset_right = 1400.0
	backdrop.offset_bottom = 960.0
	backdrop.color = Color(0.045, 0.038, 0.048, 1.0)
	root.add_child(backdrop)
	backdrop.owner = root

	var tilemap := TileMapLayer.new()
	tilemap.name = "DormMap"
	tilemap.tile_set = tileset
	var cells: Array = layout["cells"]
	for y in range(cells.size()):
		var row: Array = cells[y]
		for x in range(row.size()):
			var tname = row[x]
			if tname == null:
				continue
			var ac: Array = tile_defs[tname]["atlas"]
			tilemap.set_cell(Vector2i(x, y), 0, Vector2i(int(ac[0]), int(ac[1])))
	root.add_child(tilemap)
	tilemap.owner = root

	# Standalone Piano Trio No. 1 rug sprite above floor, below Y-sorted objects
	var rug := Sprite2D.new()
	rug.name = "PianoTrioRug"
	rug.texture = rug_tex
	rug.position = Vector2(180, 212)
	root.add_child(rug)
	rug.owner = root

	# Window snow particles clipped to the window glass area (window at col 2..3 -> x=64..128, y=11..80)
	var snow_clip := ColorRect.new()
	snow_clip.name = "WindowSnowClip"
	snow_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	snow_clip.offset_left = 76.0
	snow_clip.offset_top = 18.0
	snow_clip.offset_right = 116.0
	snow_clip.offset_bottom = 66.0
	snow_clip.color = Color(1, 1, 1, 1)
	root.add_child(snow_clip)
	snow_clip.owner = root

	var snow_mat := CanvasItemMaterial.new()
	snow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	snow_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)
	])

	var snow_parts := CPUParticles2D.new()
	snow_parts.name = "WindowSnowParticles"
	snow_parts.material = snow_mat
	snow_parts.position = Vector2(20, -4)
	snow_parts.amount = 14
	snow_parts.texture = mote_tex
	snow_parts.lifetime = 3.2
	snow_parts.preprocess = 2.0
	snow_parts.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow_parts.emission_rect_extents = Vector2(22, 2)
	snow_parts.direction = Vector2(-0.35, 1.0)
	snow_parts.spread = 18.0
	snow_parts.gravity = Vector2(-2, 14)
	snow_parts.initial_velocity_min = 8.0
	snow_parts.initial_velocity_max = 15.0
	snow_parts.scale_amount_min = 0.25
	snow_parts.scale_amount_max = 0.55
	snow_parts.color = Color(0.82, 0.9, 1.0, 0.55)
	snow_parts.color_ramp = grad
	snow_clip.add_child(snow_parts)
	snow_parts.owner = root

	# Lights
	var win_light := PointLight2D.new()
	win_light.name = "WindowNightLight"
	win_light.position = Vector2(96, 62)
	win_light.color = Color(0.46, 0.62, 0.9, 1)
	win_light.energy = 0.46
	win_light.texture = light_tex
	win_light.texture_scale = 1.85
	root.add_child(win_light)
	win_light.owner = root

	var piano_light := PointLight2D.new()
	piano_light.name = "PianoScoreLight"
	piano_light.position = Vector2(152, 82)
	piano_light.color = Color(0.88, 0.72, 0.5, 1)
	piano_light.energy = 0.26
	piano_light.texture = light_tex
	piano_light.texture_scale = 1.05
	root.add_child(piano_light)
	piano_light.owner = root

	# Corridor dim overhead lamp (cold green-amber fluorescent horror tone)
	var corr_light := PointLight2D.new()
	corr_light.name = "CorridorCeilingLight"
	corr_light.position = Vector2(528, 128)
	corr_light.color = Color(0.76, 0.84, 0.72, 1)
	corr_light.energy = 0.52
	corr_light.texture = light_tex
	corr_light.texture_scale = 2.6
	root.add_child(corr_light)
	corr_light.owner = root

	# YSort Layer (furniture + Player)
	var ysort := Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	root.add_child(ysort)
	ysort.owner = root

	var add_furniture := func(fname: String, pos: Vector2, region: Rect2, spr_off: Vector2, col_pos: Vector2, col_size: Vector2) -> StaticBody2D:
		var body := StaticBody2D.new()
		body.name = fname
		body.position = pos
		ysort.add_child(body)
		body.owner = root

		var sp := Sprite2D.new()
		sp.name = "Sprite2D"
		sp.texture = furn_tex
		sp.offset = spr_off
		sp.region_enabled = true
		sp.region_rect = region
		body.add_child(sp)
		sp.owner = root

		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		cs.position = col_pos
		var shape := RectangleShape2D.new()
		shape.size = col_size
		cs.shape = shape
		body.add_child(cs)
		cs.owner = root
		return body

	add_furniture.call("SingleBed", Vector2(58, 178), Rect2(8, 68, 44, 80), Vector2(0, -40), Vector2(0, -29), Vector2(40, 58))
	add_furniture.call("NightstandStool", Vector2(96, 116), Rect2(184, 8, 19, 26), Vector2(0, -13), Vector2(0, -5), Vector2(16, 10))
	add_furniture.call("UprightPiano", Vector2(152, 108), Rect2(8, 8, 62, 52), Vector2(0, -26), Vector2(0, -8), Vector2(58, 16))
	add_furniture.call("Bookshelf", Vector2(200, 108), Rect2(64, 68, 26, 80), Vector2(0, -40), Vector2(0, -7), Vector2(24, 14))
	var desk: StaticBody2D = add_furniture.call("ComposerDesk", Vector2(264, 128), Rect2(80, 8, 66, 52), Vector2(0, -26), Vector2(0, -9), Vector2(60, 18))
	add_furniture.call("DeskChair", Vector2(254, 140), Rect2(156, 8, 19, 42), Vector2(0, -21), Vector2(0, -5), Vector2(15, 10))
	add_furniture.call("StudentBackpack", Vector2(314, 132), Rect2(212, 8, 23, 26), Vector2(0, -13), Vector2(0, -5), Vector2(18, 10))

	# Desk lights + lamp cone
	var lamp_light := PointLight2D.new()
	lamp_light.name = "DeskLampLight"
	lamp_light.position = Vector2(18, -43)
	lamp_light.color = Color(0.96, 0.72, 0.38, 1)
	lamp_light.energy = 0.78
	lamp_light.texture = light_tex
	lamp_light.texture_scale = 1.85
	desk.add_child(lamp_light)
	lamp_light.owner = root

	var lamp_halo := PointLight2D.new()
	lamp_halo.name = "DeskLampCoreHalo"
	lamp_halo.position = Vector2(18, -43)
	lamp_halo.color = Color(1, 0.84, 0.58, 1)
	lamp_halo.energy = 0.28
	lamp_halo.texture = light_tex
	lamp_halo.texture_scale = 0.55
	desk.add_child(lamp_halo)
	lamp_halo.owner = root

	var laptop_glow := PointLight2D.new()
	laptop_glow.name = "LaptopScreenGlow"
	laptop_glow.position = Vector2(-6, -32)
	laptop_glow.color = Color(0.45, 0.7, 0.96, 1)
	laptop_glow.energy = 0.36
	laptop_glow.texture = light_tex
	laptop_glow.texture_scale = 0.85
	desk.add_child(laptop_glow)
	laptop_glow.owner = root

	var lamp_cone_mat := ShaderMaterial.new()
	lamp_cone_mat.shader = shaft_shader
	lamp_cone_mat.set_shader_parameter("ray_color", Color(0.95, 0.72, 0.38, 0.11))
	lamp_cone_mat.set_shader_parameter("beam_start_x", 0.22)
	lamp_cone_mat.set_shader_parameter("beam_width", 0.48)
	lamp_cone_mat.set_shader_parameter("angle_skew", -0.1)
	lamp_cone_mat.set_shader_parameter("spread_growth", 0.22)
	lamp_cone_mat.set_shader_parameter("ray_frequency", 4.0)
	lamp_cone_mat.set_shader_parameter("shimmer_speed", 0.25)
	lamp_cone_mat.set_shader_parameter("edge_softness", 0.38)
	lamp_cone_mat.set_shader_parameter("vertical_fade_power", 1.65)

	var lamp_cone := ColorRect.new()
	lamp_cone.name = "LampLightCone"
	lamp_cone.material = lamp_cone_mat
	lamp_cone.offset_left = -22.0
	lamp_cone.offset_top = -44.0
	lamp_cone.offset_right = 46.0
	lamp_cone.offset_bottom = 14.0
	lamp_cone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.add_child(lamp_cone)
	lamp_cone.owner = root

	# Player
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(180, 214)
	player.set_script(load("res://scripts/player.gd"))
	ysort.add_child(player)
	player.owner = root

	var pspr := Sprite2D.new()
	pspr.name = "Sprite2D"
	pspr.texture = hero_tex
	pspr.offset = Vector2(0, -18)
	pspr.hframes = 3
	pspr.vframes = 4
	player.add_child(pspr)
	pspr.owner = root

	var pcol := CollisionShape2D.new()
	pcol.name = "CollisionShape2D"
	pcol.position = Vector2(0, -4)
	var pshape := RectangleShape2D.new()
	pshape.size = Vector2(14, 8)
	pcol.shape = pshape
	player.add_child(pcol)
	pcol.owner = root

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position = Vector2(0, -18)
	cam.zoom = Vector2(3.2, 3.2)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)
	cam.owner = root

	var hlight := PointLight2D.new()
	hlight.name = "AmbientHeroLight"
	hlight.position = Vector2(0, -16)
	hlight.color = Color(0.92, 0.78, 0.62, 1)
	hlight.energy = 0.42
	hlight.texture = light_tex
	hlight.texture_scale = 1.35
	player.add_child(hlight)
	hlight.owner = root

	# Volumetric Moonlight God-Rays from Room Window
	var moon_mat := ShaderMaterial.new()
	moon_mat.shader = shaft_shader
	moon_mat.set_shader_parameter("ray_color", Color(0.52, 0.68, 0.9, 0.13))
	moon_mat.set_shader_parameter("beam_start_x", 0.06)
	moon_mat.set_shader_parameter("beam_width", 0.4)
	moon_mat.set_shader_parameter("angle_skew", 0.38)
	moon_mat.set_shader_parameter("spread_growth", 0.16)
	moon_mat.set_shader_parameter("ray_frequency", 5.0)
	moon_mat.set_shader_parameter("shimmer_speed", 0.28)
	moon_mat.set_shader_parameter("edge_softness", 0.36)
	moon_mat.set_shader_parameter("vertical_fade_power", 1.55)

	var moon_rays := ColorRect.new()
	moon_rays.name = "WindowGodRays"
	moon_rays.material = moon_mat
	moon_rays.offset_left = 60.0
	moon_rays.offset_top = 18.0
	moon_rays.offset_right = 172.0
	moon_rays.offset_bottom = 148.0
	moon_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(moon_rays)
	moon_rays.owner = root

	# Subtle matte dust specks
	var dust_moon := CPUParticles2D.new()
	dust_moon.name = "MoonlightDustParticles"
	dust_moon.material = snow_mat
	dust_moon.position = Vector2(106, 86)
	dust_moon.amount = 9
	dust_moon.texture = mote_tex
	dust_moon.lifetime = 7.5
	dust_moon.preprocess = 4.0
	dust_moon.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust_moon.emission_rect_extents = Vector2(26, 30)
	dust_moon.direction = Vector2(0.3, 0.8)
	dust_moon.spread = 120.0
	dust_moon.gravity = Vector2(0.4, 1.2)
	dust_moon.initial_velocity_min = 0.8
	dust_moon.initial_velocity_max = 2.2
	dust_moon.damping_min = 0.2
	dust_moon.damping_max = 0.5
	dust_moon.scale_amount_min = 0.4
	dust_moon.scale_amount_max = 0.65
	dust_moon.color = Color(0.62, 0.68, 0.76, 0.18)
	dust_moon.color_ramp = grad
	root.add_child(dust_moon)
	dust_moon.owner = root

	var dust_warm := CPUParticles2D.new()
	dust_warm.name = "WarmRoomDustParticles"
	dust_warm.material = snow_mat
	dust_warm.position = Vector2(256, 108)
	dust_warm.amount = 10
	dust_warm.texture = mote_tex
	dust_warm.lifetime = 8.0
	dust_warm.preprocess = 5.0
	dust_warm.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust_warm.emission_rect_extents = Vector2(36, 28)
	dust_warm.direction = Vector2(0, -1)
	dust_warm.spread = 160.0
	dust_warm.gravity = Vector2(0, -0.8)
	dust_warm.initial_velocity_min = 0.6
	dust_warm.initial_velocity_max = 1.8
	dust_warm.damping_min = 0.2
	dust_warm.damping_max = 0.5
	dust_warm.scale_amount_min = 0.4
	dust_warm.scale_amount_max = 0.65
	dust_warm.color = Color(0.76, 0.68, 0.56, 0.18)
	dust_warm.color_ramp = grad
	root.add_child(dust_warm)
	dust_warm.owner = root

	var canvas_mod := CanvasModulate.new()
	canvas_mod.name = "CanvasModulate"
	canvas_mod.color = Color(0.46, 0.44, 0.48, 1)
	root.add_child(canvas_mod)
	canvas_mod.owner = root

	var atmo_layer := CanvasLayer.new()
	atmo_layer.name = "AtmosphereLayer"
	root.add_child(atmo_layer)
	atmo_layer.owner = root

	var film_mat := ShaderMaterial.new()
	film_mat.shader = film_shader
	film_mat.set_shader_parameter("tilt_shift_amount", 1.55)
	film_mat.set_shader_parameter("focus_center_y", 0.5)
	film_mat.set_shader_parameter("focus_half_band", 0.22)
	film_mat.set_shader_parameter("bloom_strength", 0.16)
	film_mat.set_shader_parameter("bloom_threshold", 0.72)
	film_mat.set_shader_parameter("ca_strength", 0.0022)
	film_mat.set_shader_parameter("vignette_strength", 0.74)
	film_mat.set_shader_parameter("grain_strength", 0.022)
	film_mat.set_shader_parameter("sepia_mix", 0.18)
	film_mat.set_shader_parameter("contrast_boost", 1.12)

	var film_rect := ColorRect.new()
	film_rect.name = "FilmEffect"
	film_rect.material = film_mat
	film_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	film_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmo_layer.add_child(film_rect)
	film_rect.owner = root

	var packed := PackedScene.new()
	var perr := packed.pack(root)
	var serr := ResourceSaver.save(packed, "res://dorm_modular.tscn")
	print("Packed dorm_modular.tscn pack_err=", perr, " save_err=", serr)
	quit()
