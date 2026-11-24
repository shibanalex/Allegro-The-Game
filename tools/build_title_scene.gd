@tool
extends SceneTree

func _init() -> void:
	var title_bg_tex: Texture2D = load("res://assets/title/title_piano_bg.png")
	var mote_tex: Texture2D = load("res://assets/particles/dust_mote.png")
	var film_shader: Shader = load("res://assets/shaders/night_film.gdshader")

	var root := Control.new()
	root.name = "TitleScreen"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set_script(load("res://scripts/title_screen.gd"))

	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.027, 0.031, 0.051, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	root.add_child(bg)
	bg.owner = root

	var title_art := TextureRect.new()
	title_art.name = "TitleArt"
	title_art.texture = title_bg_tex
	title_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	title_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_art.show_behind_parent = true
	title_art.modulate = Color(0.92, 0.94, 0.98, 0.90)
	root.add_child(title_art)
	title_art.owner = root

	# Quiet ambient winter snow particles floating gently behind the title
	var snow_grad := Gradient.new()
	snow_grad.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	snow_grad.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(0.82, 0.88, 0.96, 0.22), Color(0.82, 0.88, 0.96, 0.20), Color(1, 1, 1, 0)
	])

	var snow := CPUParticles2D.new()
	snow.name = "MenuSnow"
	snow.position = Vector2(576, -20)
	snow.amount = 28
	snow.texture = mote_tex
	snow.lifetime = 8.0
	snow.preprocess = 5.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(960, 10)
	snow.direction = Vector2(-0.18, 1.0)
	snow.spread = 15.0
	snow.gravity = Vector2(-1.5, 6.0)
	snow.initial_velocity_min = 16.0
	snow.initial_velocity_max = 32.0
	snow.scale_amount_min = 0.35
	snow.scale_amount_max = 0.75
	snow.color_ramp = snow_grad
	snow.show_behind_parent = true
	root.add_child(snow)
	snow.owner = root

	# Subtle cohesive VHS/paper tone layer matching the house scene
	var atmo_layer := CanvasLayer.new()
	atmo_layer.name = "AtmosphereLayer"
	root.add_child(atmo_layer)
	atmo_layer.owner = root

	var film_mat := ShaderMaterial.new()
	film_mat.shader = film_shader
	film_mat.set_shader_parameter("tilt_shift_amount", 0.0)
	film_mat.set_shader_parameter("bloom_strength", 0.08)
	film_mat.set_shader_parameter("bloom_threshold", 0.80)
	film_mat.set_shader_parameter("ca_strength", 0.0004)
	film_mat.set_shader_parameter("vignette_strength", 0.40)
	film_mat.set_shader_parameter("grain_strength", 0.010)
	film_mat.set_shader_parameter("sepia_mix", 0.02)
	film_mat.set_shader_parameter("contrast_boost", 1.02)
	film_mat.set_shader_parameter("paper_texture_strength", 0.012)
	film_mat.set_shader_parameter("desaturate_amount", 0.16)
	film_mat.set_shader_parameter("melancholy_grade", 0.35)
	film_mat.set_shader_parameter("vhs_strength", 0.24)

	var film_rect := ColorRect.new()
	film_rect.name = "FilmEffect"
	film_rect.material = film_mat
	film_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	film_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmo_layer.add_child(film_rect)
	film_rect.owner = root

	var packed := PackedScene.new()
	var perr := packed.pack(root)
	var serr := ResourceSaver.save(packed, "res://title_screen.tscn")
	print("Packed title_screen.tscn pack_err=", perr, " save_err=", serr)
	root.free()
	quit()
