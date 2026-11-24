@tool
extends SceneTree

func _init() -> void:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(AudioServer.bus_count - 1)

	# Bus 1: Music (100% dry, zero reverb)
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "Music")
	AudioServer.set_bus_send(1, "Master")

	# Bus 2: SFX (general dry effects)
	AudioServer.add_bus(2)
	AudioServer.set_bus_name(2, "SFX")
	AudioServer.set_bus_send(2, "Master")

	# Bus 3: Footsteps (damped low-pass + small wooden room reverb -> SFX)
	AudioServer.add_bus(3)
	AudioServer.set_bus_name(3, "Footsteps")
	AudioServer.set_bus_send(3, "SFX")

	var lpf := AudioEffectLowPassFilter.new()
	lpf.cutoff_hz = 1900.0
	lpf.resonance = 0.5
	lpf.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(3, lpf, 0)

	var rev := AudioEffectReverb.new()
	rev.room_size = 0.28
	rev.damping = 0.75
	rev.spread = 0.60
	rev.hipass = 0.28
	rev.dry = 0.72
	rev.wet = 0.26
	AudioServer.add_bus_effect(3, rev, 1)

	# Bus 4: MenuUI (quieter + atmospheric hall reverb -> SFX)
	AudioServer.add_bus(4)
	AudioServer.set_bus_name(4, "MenuUI")
	AudioServer.set_bus_send(4, "SFX")
	AudioServer.set_bus_volume_db(4, -10.5)

	var menu_lpf := AudioEffectLowPassFilter.new()
	menu_lpf.cutoff_hz = 5200.0
	menu_lpf.resonance = 0.5
	menu_lpf.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(4, menu_lpf, 0)

	var menu_rev := AudioEffectReverb.new()
	menu_rev.room_size = 0.68
	menu_rev.damping = 0.52
	menu_rev.spread = 0.85
	menu_rev.hipass = 0.18
	menu_rev.dry = 0.62
	menu_rev.wet = 0.44
	AudioServer.add_bus_effect(4, menu_rev, 1)

	var err := ResourceSaver.save(AudioServer.generate_bus_layout(), "res://default_bus_layout.tres")
	print("Saved default_bus_layout.tres err=", err)
	quit()
