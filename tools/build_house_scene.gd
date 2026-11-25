@tool
extends SceneTree

func _init() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tilesets/house_test_layout.json"))
	var tiles_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tilesets/house_tiles.json"))
	var tile_defs: Dictionary = tiles_json["tiles"]

	var tileset: TileSet = load("res://assets/tilesets/house_tileset.tres")
	var furn_tileset: TileSet = load("res://assets/tilesets/house_furniture_tileset.tres")
	var props_tileset: TileSet = load("res://assets/tilesets/house_props_tileset.tres")
	var furn_atlas_tex: Texture2D = load("res://assets/materials/house_furniture_atlas_canvas.tres")
	var hero_tex: Texture2D = load("res://assets/materials/hero_allegro_sheet_canvas.tres")
	var light_radial: Texture2D = load("res://assets/lights/light_radial_smooth.png")
	var light_window: Texture2D = load("res://assets/lights/light_window_beam.png")
	var light_lamp: Texture2D = load("res://assets/lights/light_lamp_cone.png")
	var mote_tex: Texture2D = load("res://assets/particles/dust_mote.png")
	var film_shader: Shader = load("res://assets/shaders/night_film.gdshader")
	var shaft_shader: Shader = load("res://assets/shaders/light_shaft.gdshader")
	var shadow_script: Script = load("res://scripts/dynamic_shadow.gd")

	var root := Node2D.new()
	root.name = "HouseModular"
	root.set_script(load("res://scripts/room_atmosphere.gd"))

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.offset_left = -640.0
	backdrop.offset_top = -480.0
	backdrop.offset_right = 1800.0
	backdrop.offset_bottom = 1200.0
	backdrop.color = Color(0.032, 0.030, 0.042, 1.0)
	root.add_child(backdrop)
	backdrop.owner = root

	var tilemap := TileMapLayer.new()
	tilemap.name = "HouseMap"
	tilemap.tile_set = tileset
	root.add_child(tilemap)
	tilemap.owner = root

	# YSort Layer: Hero room + foreground south cutaway walltops (so feet tuck behind southern walls)
	var ysort := Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true

	var walltop_fg := TileMapLayer.new()
	walltop_fg.name = "WallTopMap"
	walltop_fg.tile_set = tileset
	walltop_fg.y_sort_enabled = true

	var cells: Array = layout["cells"]
	var fg_cap_ac: Array = tile_defs["passage_cap_fg"]["atlas"]
	for y in range(cells.size()):
		var row: Array = cells[y]
		for x in range(row.size()):
			var tname = row[x]
			if tname == null:
				continue
			var ac: Array = tile_defs[tname]["atlas"]
			if tname.begins_with("walltop_") and (int(tname.split("_")[1]) & 4) != 0:
				walltop_fg.set_cell(Vector2i(x, y), 0, Vector2i(int(ac[0]), int(ac[1])))
			else:
				tilemap.set_cell(Vector2i(x, y), 0, Vector2i(int(ac[0]), int(ac[1])))
				if tname == "passage_cap":
					walltop_fg.set_cell(Vector2i(x, y), 0, Vector2i(int(fg_cap_ac[0]), int(fg_cap_ac[1])))

	# Winter morning snow particles clipped to hero room window at tile (2, 8) -> px (64, 256)
	var snow_clip := ColorRect.new()
	snow_clip.name = "WindowSnowClip"
	snow_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	snow_clip.offset_left = 76.0
	snow_clip.offset_top = 270.0
	snow_clip.offset_right = 116.0
	snow_clip.offset_bottom = 304.0
	snow_clip.color = Color(1, 1, 1, 1)
	root.add_child(snow_clip)
	snow_clip.owner = root

	var snow_mat := CanvasItemMaterial.new()
	snow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	snow_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0.65), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.65), Color(1, 1, 1, 0)
	])

	var snow_parts := CPUParticles2D.new()
	snow_parts.name = "WindowSnowParticles"
	snow_parts.material = snow_mat
	snow_parts.position = Vector2(20, -4)
	snow_parts.amount = 18
	snow_parts.texture = mote_tex
	snow_parts.lifetime = 3.0
	snow_parts.preprocess = 2.0
	snow_parts.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow_parts.emission_rect_extents = Vector2(22, 2)
	snow_parts.direction = Vector2(-0.35, 1.0)
	snow_parts.spread = 18.0
	snow_parts.gravity = Vector2(-2, 14)
	snow_parts.initial_velocity_min = 8.0
	snow_parts.initial_velocity_max = 15.0
	snow_parts.scale_amount_min = 0.28
	snow_parts.scale_amount_max = 0.58
	snow_parts.color = Color(0.92, 0.96, 1.0, 0.72)
	snow_parts.color_ramp = grad
	snow_clip.add_child(snow_parts)
	snow_parts.owner = root

	var configure_shadow := func(pl: PointLight2D, smooth: float, scol: Color) -> void:
		pl.shadow_enabled = true
		pl.shadow_filter = Light2D.SHADOW_FILTER_PCF13
		pl.shadow_filter_smooth = smooth
		pl.shadow_color = scol
		pl.shadow_item_cull_mask = 1

	# Directional overcast winter morning daylight spilling through the hero's window with real wall shadows
	var win_light := PointLight2D.new()
	win_light.name = "WindowMorningLight"
	win_light.position = Vector2(102, 306)
	win_light.color = Color(0.68, 0.83, 1.0, 1.0)
	win_light.energy = 0.94
	win_light.height = 38.0
	win_light.texture = light_window
	win_light.texture_scale = 1.65
	configure_shadow.call(win_light, 3.6, Color(0.03, 0.04, 0.08, 0.72))
	root.add_child(win_light)
	win_light.owner = root

	var add_point := func(lname: String, pos: Vector2, col: Color, energy: float, scale_v: float, height_v: float, shadow_col: Color) -> PointLight2D:
		var pl := PointLight2D.new()
		pl.name = lname
		pl.position = pos
		pl.color = col
		pl.energy = energy
		pl.height = height_v
		pl.texture = light_radial
		pl.texture_scale = scale_v
		configure_shadow.call(pl, 3.8, shadow_col)
		root.add_child(pl)
		pl.owner = root
		return pl

	# Room PointLight2D sources bounded by wall LightOccluder2D nodes.
	add_point.call("HallwayWarmLight", Vector2(496, 348), Color(0.98, 0.81, 0.60, 1.0), 0.96, 2.65, 42.0, Color(0.04, 0.03, 0.06, 0.74))
	add_point.call("EntryLight", Vector2(896, 146), Color(0.74, 0.84, 0.98, 1.0), 0.82, 2.20, 40.0, Color(0.03, 0.04, 0.07, 0.72))
	add_point.call("KitchenLight", Vector2(928, 382), Color(1.0, 0.83, 0.60, 1.0), 0.94, 2.40, 42.0, Color(0.04, 0.03, 0.05, 0.74))
	add_point.call("BrotherRoomLight", Vector2(392, 164), Color(0.68, 0.80, 0.96, 1.0), 0.82, 2.35, 40.0, Color(0.03, 0.04, 0.07, 0.74))
	add_point.call("ParentsRoomLight", Vector2(648, 164), Color(0.86, 0.80, 0.74, 1.0), 0.76, 2.25, 40.0, Color(0.04, 0.04, 0.07, 0.74))

	root.add_child(ysort)
	ysort.owner = root
	ysort.add_child(walltop_fg)
	walltop_fg.owner = root

	# Ready-to-paint TileMapLayers in Godot Editor for stamping furniture, rugs & small props on the 32x32 grid
	var furn_map := TileMapLayer.new()
	furn_map.name = "FurnitureMap"
	furn_map.tile_set = furn_tileset
	furn_map.y_sort_enabled = true
	ysort.add_child(furn_map)
	furn_map.owner = root

	var props_map := TileMapLayer.new()
	props_map.name = "PropsMap"
	props_map.tile_set = props_tileset
	props_map.y_sort_enabled = true
	ysort.add_child(props_map)
	props_map.owner = root

	var add_shadow := func(parent_node: Node2D, c_size: Vector2, c_off: Vector2, c_alpha: float, is_rect: bool, cast_en: bool, cast_rad: Vector2, cast_len: float, cast_a: float) -> void:
		var sh := Node2D.new()
		sh.name = "DynamicShadow"
		sh.set_script(shadow_script)
		sh.set("contact_size", c_size)
		sh.set("contact_offset", c_off)
		sh.set("contact_alpha", c_alpha)
		sh.set("is_rect_contact", is_rect)
		sh.set("cast_enabled", cast_en)
		sh.set("cast_radius", cast_rad)
		sh.set("cast_max_length", cast_len)
		sh.set("cast_alpha", cast_a)
		parent_node.add_child(sh)
		sh.owner = root

	var add_furniture := func(fname: String, pos: Vector2, tex: Texture2D, use_region: bool, region: Rect2, spr_off: Vector2, col_pos: Vector2, col_size: Vector2) -> StaticBody2D:
		var body := StaticBody2D.new()
		body.name = fname
		body.position = pos
		ysort.add_child(body)
		body.owner = root

		var sp := Sprite2D.new()
		sp.name = "Sprite2D"
		sp.texture = tex
		sp.offset = spr_off
		sp.region_enabled = use_region
		if use_region:
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

	# Bed tucked against left wall right next to the winter window (hero room floor y=320..480, x=32..256)
	var bed: StaticBody2D = add_furniture.call("SingleBed", Vector2(58, 404), furn_atlas_tex, true, Rect2(0, 0, 64, 96), Vector2(0, -48), Vector2(0, -29), Vector2(40, 58))
	add_shadow.call(bed, Vector2(42, 62), Vector2(0, -30), 0.42, true, true, Vector2(18, 22), 11.0, 0.16)

	var desk: StaticBody2D = add_furniture.call("SimpleDesk", Vector2(194, 344), furn_atlas_tex, true, Rect2(64, 0, 96, 64), Vector2(0, -32), Vector2(0, -9), Vector2(60, 18))
	add_shadow.call(desk, Vector2(56, 18), Vector2(1, -6), 0.46, true, true, Vector2(20, 8), 10.0, 0.18)

	var chair: StaticBody2D = add_furniture.call("DeskChair", Vector2(188, 362), furn_atlas_tex, true, Rect2(128, 64, 32, 64), Vector2(0, -32), Vector2(0, -5), Vector2(15, 10))
	add_shadow.call(chair, Vector2(16, 8), Vector2(0, -3), 0.42, false, true, Vector2(7, 4), 12.0, 0.22)

	# Kitchen / Dining Room furniture (flush wall unit on right partition wing + dining table & 2 side chairs)
	var kwu: StaticBody2D = add_furniture.call("KitchenWallUnit", Vector2(976, 340), furn_atlas_tex, true, Rect2(0, 96, 96, 96), Vector2(0, -48), Vector2(0, -10), Vector2(76, 20))
	add_shadow.call(kwu, Vector2(78, 14), Vector2(0, -5), 0.44, true, false, Vector2(20, 8), 8.0, 0.16)

	var ktbl: StaticBody2D = add_furniture.call("KitchenTable", Vector2(936, 432), furn_atlas_tex, true, Rect2(192, 128, 64, 64), Vector2(0, -32), Vector2(0, -12), Vector2(56, 24))
	add_shadow.call(ktbl, Vector2(56, 22), Vector2(0, -9), 0.46, true, true, Vector2(20, 10), 11.0, 0.20)

	var kchl: StaticBody2D = add_furniture.call("KitchenChairLeft", Vector2(894, 426), furn_atlas_tex, true, Rect2(256, 64, 32, 64), Vector2(0, -32), Vector2(0, -6), Vector2(14, 12))
	add_shadow.call(kchl, Vector2(15, 8), Vector2(0, -3), 0.42, false, true, Vector2(7, 4), 12.0, 0.22)

	var kchr: StaticBody2D = add_furniture.call("KitchenChairRight", Vector2(978, 426), furn_atlas_tex, true, Rect2(288, 64, 32, 64), Vector2(0, -32), Vector2(0, -6), Vector2(14, 12))
	add_shadow.call(kchr, Vector2(15, 8), Vector2(0, -3), 0.42, false, true, Vector2(7, 4), 12.0, 0.22)

	# Warm tungsten desk lamp (matching the lit brass lamp on SimpleDesk!) with real-time wall shadows
	var desk_lamp := PointLight2D.new()
	desk_lamp.name = "DeskLampLight"
	desk_lamp.position = Vector2(15, -24)
	desk_lamp.color = Color(1.0, 0.76, 0.44, 1.0)
	desk_lamp.energy = 0.96
	desk_lamp.height = 28.0
	desk_lamp.texture = light_lamp
	desk_lamp.texture_scale = 1.55
	configure_shadow.call(desk_lamp, 2.8, Color(0.04, 0.03, 0.05, 0.65))
	desk.add_child(desk_lamp)
	desk_lamp.owner = root

	var desk_halo := PointLight2D.new()
	desk_halo.name = "DeskLampCoreHalo"
	desk_halo.position = Vector2(18, -44)
	desk_halo.color = Color(1.0, 0.88, 0.62, 1.0)
	desk_halo.energy = 0.28
	desk_halo.height = 14.0
	desk_halo.texture = light_radial
	desk_halo.texture_scale = 0.42
	desk.add_child(desk_halo)
	desk_halo.owner = root

	var laptop_glow := PointLight2D.new()
	laptop_glow.name = "LaptopScreenGlow"
	laptop_glow.position = Vector2(3, -39)
	laptop_glow.color = Color(0.42, 0.76, 1.0, 1.0)
	laptop_glow.energy = 0.34
	laptop_glow.height = 16.0
	laptop_glow.texture = light_radial
	laptop_glow.texture_scale = 0.62
	desk.add_child(laptop_glow)
	laptop_glow.owner = root

	# Hero spawns waking up beside the bed (FLOATING motion_mode + smooth CapsuleShape2D prevents tile/door snagging)
	var player := CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(104, 384)
	player.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	player.set_script(load("res://scripts/player.gd"))
	ysort.add_child(player)
	player.owner = root

	add_shadow.call(player, Vector2(16, 7), Vector2(0, 0), 0.56, false, true, Vector2(7.5, 4.5), 24.0, 0.44)

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
	pcol.rotation = PI * 0.5
	var pshape := CapsuleShape2D.new()
	pshape.radius = 4.0
	pshape.height = 14.0
	pcol.shape = pshape
	player.add_child(pcol)
	pcol.owner = root

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position = Vector2(0, -18)
	cam.zoom = Vector2(3.0, 3.0)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)
	cam.owner = root

	var hlight := PointLight2D.new()
	hlight.name = "AmbientHeroLight"
	hlight.position = Vector2(0, -18)
	hlight.color = Color(0.80, 0.84, 0.92, 1.0)
	hlight.energy = 0.16
	hlight.height = 26.0
	hlight.texture = light_radial
	hlight.texture_scale = 0.95
	player.add_child(hlight)
	hlight.owner = root

	# Overcast winter morning volumetric rays from the hero room window
	var morning_mat := ShaderMaterial.new()
	morning_mat.shader = shaft_shader
	morning_mat.set_shader_parameter("ray_color", Color(0.68, 0.82, 0.96, 0.115))
	morning_mat.set_shader_parameter("beam_start_x", 0.08)
	morning_mat.set_shader_parameter("beam_width", 0.44)
	morning_mat.set_shader_parameter("angle_skew", 0.34)
	morning_mat.set_shader_parameter("spread_growth", 0.18)
	morning_mat.set_shader_parameter("ray_frequency", 5.0)
	morning_mat.set_shader_parameter("shimmer_speed", 0.25)
	morning_mat.set_shader_parameter("edge_softness", 0.38)
	morning_mat.set_shader_parameter("vertical_fade_power", 1.45)

	var morning_rays := ColorRect.new()
	morning_rays.name = "WindowGodRays"
	morning_rays.material = morning_mat
	morning_rays.offset_left = 60.0
	morning_rays.offset_top = 268.0
	morning_rays.offset_right = 176.0
	morning_rays.offset_bottom = 386.0
	morning_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(morning_rays)
	morning_rays.owner = root

	# Delicate winter-morning dust motes drifting across hero's room sunbeam
	var mote_mat := CanvasItemMaterial.new()
	mote_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mote_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	var mote_grad := Gradient.new()
	mote_grad.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	mote_grad.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(0.86, 0.92, 1.0, 0.30), Color(0.98, 0.93, 0.84, 0.22), Color(1, 1, 1, 0)
	])

	var room_motes := CPUParticles2D.new()
	room_motes.name = "MorningDustMotes"
	room_motes.material = mote_mat
	room_motes.position = Vector2(132, 332)
	room_motes.amount = 14
	room_motes.texture = mote_tex
	room_motes.lifetime = 5.5
	room_motes.preprocess = 3.0
	room_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	room_motes.emission_rect_extents = Vector2(76, 44)
	room_motes.direction = Vector2(0.4, -0.2)
	room_motes.spread = 35.0
	room_motes.gravity = Vector2(0.5, -1.2)
	room_motes.initial_velocity_min = 1.5
	room_motes.initial_velocity_max = 4.5
	room_motes.scale_amount_min = 0.16
	room_motes.scale_amount_max = 0.34
	room_motes.color_ramp = mote_grad
	root.add_child(room_motes)
	room_motes.owner = root

	# Deep moody winter ambient base so dynamic PointLight2D pools, normal highlights & shadows sing!
	var canvas_mod := CanvasModulate.new()
	canvas_mod.name = "CanvasModulate"
	canvas_mod.color = Color(0.41, 0.45, 0.55, 1.0)
	root.add_child(canvas_mod)
	canvas_mod.owner = root

	var atmo_layer := CanvasLayer.new()
	atmo_layer.name = "AtmosphereLayer"
	root.add_child(atmo_layer)
	atmo_layer.owner = root

	var film_mat := ShaderMaterial.new()
	film_mat.shader = film_shader
	film_mat.set_shader_parameter("tilt_shift_amount", 0.0)
	film_mat.set_shader_parameter("focus_center_y", 0.5)
	film_mat.set_shader_parameter("focus_half_band", 0.32)
	film_mat.set_shader_parameter("bloom_strength", 0.16)
	film_mat.set_shader_parameter("bloom_threshold", 0.70)
	film_mat.set_shader_parameter("ca_strength", 0.0005)
	film_mat.set_shader_parameter("vignette_strength", 0.30)
	film_mat.set_shader_parameter("grain_strength", 0.011)
	film_mat.set_shader_parameter("sepia_mix", 0.03)
	film_mat.set_shader_parameter("contrast_boost", 1.04)
	film_mat.set_shader_parameter("paper_texture_strength", 0.014)
	film_mat.set_shader_parameter("desaturate_amount", 0.20)
	film_mat.set_shader_parameter("melancholy_grade", 0.44)
	film_mat.set_shader_parameter("vhs_strength", 0.28)

	var film_rect := ColorRect.new()
	film_rect.name = "FilmEffect"
	film_rect.material = film_mat
	film_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	film_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmo_layer.add_child(film_rect)
	film_rect.owner = root

	var trans_layer := CanvasLayer.new()
	trans_layer.name = "TransitionLayer"
	trans_layer.layer = 10
	root.add_child(trans_layer)
	trans_layer.owner = root

	var fade_rect := ColorRect.new()
	fade_rect.name = "FadeOverlay"
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0.025, 0.025, 0.035, 1.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trans_layer.add_child(fade_rect)
	fade_rect.owner = root

	var packed := PackedScene.new()
	var perr := packed.pack(root)
	var serr := ResourceSaver.save(packed, "res://house_modular.tscn")
	print("Packed house_modular.tscn pack_err=", perr, " save_err=", serr)
	root.free()
	quit()
