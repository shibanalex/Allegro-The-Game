@tool
extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://house_modular.tscn")
	var root: Node2D = packed.instantiate()
	get_root().add_child(root)

	# Force a physics step so TileMapLayer bakes its collision shapes into PhysicsServer2D
	await process_frame
	await physics_frame
	await physics_frame

	var space := root.get_world_2d().direct_space_state
	var shape := CapsuleShape2D.new()
	shape.radius = 4.0
	shape.height = 14.0  # exact rotated Player capsule collision shape

	var player := root.get_node_or_null("YSort/Player") as CollisionObject2D
	var exclude_rids: Array[RID] = []
	if player != null:
		exclude_rids.append(player.get_rid())

	var can_stand := func(pos: Vector2) -> bool:
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = shape
		q.transform = Transform2D(PI * 0.5, pos + Vector2(0, -4))
		q.collision_mask = 1
		q.exclude = exclude_rids
		return space.intersect_shape(q, 4).is_empty()

	var checks := [
		# Walkable floors & doorways (2-tile wall grid)
		["Hero spawn floor", Vector2(104, 384), true],
		["Hero -> Corridor threshold", Vector2(272, 368), true],
		["Corridor center", Vector2(496, 368), true],
		["Corridor -> Entry threshold", Vector2(784, 368), true],
		["Entry floor before front door", Vector2(896, 120), true],
		["Kitchen floor", Vector2(896, 384), true],
		["Brother hall_passage bottom (11.5, 9)", Vector2(384, 304), true],
		["Brother hall_passage top (11.5, 8)", Vector2(384, 272), true],
		["Brother passage_cap (11.5, 7)", Vector2(384, 240), true],
		["Brother room floor (11.5, 5)", Vector2(384, 176), true],
		["Parents hall_passage top (19.5, 8)", Vector2(640, 272), true],
		["Parents passage_cap (19.5, 7)", Vector2(640, 240), true],
		["Parents room floor (19.5, 5)", Vector2(640, 176), true],
		["Brother south wall tuck-in at (14, y=233)", Vector2(464, 233), true],
		["Entry <-> Dining partition opening mid (28, 9)", Vector2(896, 288), true],
		["Entry <-> Dining partition opening top (28, 7)", Vector2(896, 240), true],
		["Kitchen walkway between counter and table", Vector2(936, 380), true],
		["Kitchen walkway below dining table", Vector2(936, 460), true],
		# Solid walls / props / partition walls (MUST ALL BE BLOCKED = false)
		["Corridor hall_wall_top at x=15", Vector2(496, 272), false],
		["Corridor hall_wall_bot at x=15", Vector2(496, 304), false],
		["Entry/Dining left partition wing (25.5, 9)", Vector2(832, 288), false],
		["Entry/Dining right partition wing (30.5, 9)", Vector2(992, 288), false],
		["Kitchen wall unit footprint", Vector2(976, 332), false],
		["Kitchen dining table footprint", Vector2(936, 420), false],
		["Brother/Corridor partition walltop at (14, 7)", Vector2(464, 240), false],
		["Hero room_wall_top at (5, 8)", Vector2(176, 272), false],
		["Hero room_wall_bot at (5, 9)", Vector2(176, 304), false],
		["Hero room_window at (2.5, 8.5)", Vector2(96, 288), false],
		["Entry front hall_door at (27.5, 1.5)", Vector2(896, 64), false],
		["Entry hall_coatrack at (29.5, 1.5)", Vector2(960, 64), false],
		["Brother hall_passage left jamb at x=354", Vector2(354, 288), false],
		["Brother hall_passage right jamb at x=414", Vector2(414, 288), false],
		["Between Brother & Parents wall at (16, 4)", Vector2(528, 144), false],
	]

	var failed := 0
	for item in checks:
		var label: String = item[0]
		var pos: Vector2 = item[1]
		var expected: bool = item[2]
		var actual: bool = can_stand.call(pos)
		var ok := (actual == expected)
		if not ok:
			failed += 1
		print("[%s] %s @ %s -> clear=%s (expected=%s)" % ["PASS" if ok else "FAIL", label, pos, actual, expected])

	print("COLLISION_VERIFY_FAILED=", failed)

	# Simulate actual CharacterBody2D.move_and_slide() walks to detect snagging or motion_mode stalls
	var body := player as CharacterBody2D
	if body != null:
		body.set_physics_process(false)
		var walk_test := func(wlabel: String, start: Vector2, vel: Vector2, steps: int) -> Vector2:
			body.global_position = start
			body.velocity = vel
			var zero_steps := 0
			for _i in range(steps):
				var before := body.global_position
				body.velocity = vel
				body.move_and_slide()
				await physics_frame
				if body.global_position.distance_to(before) < 0.05:
					zero_steps += 1
			print("[WALK] %s: %s -> %s (stalled_frames=%d/%d)" % [wlabel, start, body.global_position, zero_steps, steps])
			return body.global_position

		await walk_test.call("Hero -> Corridor right", Vector2(220, 384), Vector2(88, 0), 40)
		await walk_test.call("Corridor -> Hero south wall slide left", Vector2(320, 408), Vector2(-88, -20), 50)
		await walk_test.call("Corridor -> Brother passage UP (capsule corner glide)", Vector2(369, 336), Vector2(0, -88), 70)
		await walk_test.call("Brother south wall Slide Right @ y=232", Vector2(310, 232), Vector2(88, 20), 60)
		await walk_test.call("Corridor -> Kitchen right", Vector2(720, 384), Vector2(88, 0), 50)
		await walk_test.call("Entry -> Dining straight DOWN through partition", Vector2(896, 150), Vector2(0, 88), 100)
	print("Player motion_mode=", body.motion_mode, " safe_margin=", body.safe_margin)

	# Verify audio bus separation and Filler theme WAV import/loop
	print("Audio buses count=", AudioServer.bus_count, " Music=", AudioServer.get_bus_index("Music"), " SFX=", AudioServer.get_bus_index("SFX"), " Footsteps=", AudioServer.get_bus_index("Footsteps"))
	var filler := load("res://assets/audio/Filler theme.wav") as AudioStreamWAV
	if filler == null:
		failed += 1
		print("[FAIL] Filler theme WAV failed to load")
	else:
		print("Filler WAV format=", filler.format, " rate=", filler.mix_rate, " len=%.2fs" % filler.get_length(), " import_loop=", filler.loop_mode, " loop_end=", filler.loop_end)
		# Verify room_atmosphere sets loop_mode cleanly at runtime
		root._ready()
		print("[PASS] Filler theme WAV ready, loop_mode=", filler.loop_mode, " loop_end=", filler.loop_end, " length=%.2fs" % filler.get_length())
		if filler.loop_mode != AudioStreamWAV.LOOP_FORWARD or filler.loop_end <= 0:
			failed += 1
			print("[FAIL] Loop mode did not activate!")
	var f_bus := AudioServer.get_bus_index("Footsteps")
	var m_bus := AudioServer.get_bus_index("Music")
	if f_bus < 0 or m_bus < 0 or AudioServer.get_bus_effect_count(m_bus) != 0 or AudioServer.get_bus_effect_count(f_bus) < 2:
		failed += 1
		print("[FAIL] Bus layout mismatch")
	else:
		print("[PASS] Music bus dry (0 fx); Footsteps bus has lowpass + room reverb (%d fx)" % AudioServer.get_bus_effect_count(f_bus))

	root.queue_free()
	await process_frame
	quit(failed)
