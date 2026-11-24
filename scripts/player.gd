extends CharacterBody2D

@export var speed: float = 88.0
@export var step_fps: float = 5.86
@export var base_offset_y: float = -18.0
@export var stride_px: float = 30.0
@export var first_step_px: float = 10.0
@export var can_move: bool = true

@onready var sprite: Sprite2D = $Sprite2D

const WOOD_STEP_SE := preload("res://assets/audio/se/wood_step.wav")

# Rows in 3x4 spritesheet: 0=Down, 1=Left, 2=Right, 3=Up
var facing_row: int = 0
var anim_timer: float = 0.0
var was_moving: bool = false
var next_start_idx: int = 0
var step_dist_accum: float = 0.0
var next_step_threshold: float = 10.0
var step_parity: int = 0
const WALK_CYCLE: Array[int] = [1, 0, 2, 0]


func _physics_process(delta: float) -> void:
	if not can_move:
		was_moving = false
		step_dist_accum = 0.0
		next_step_threshold = first_step_px
		velocity = Vector2.ZERO
		sprite.frame = facing_row * 3
		sprite.offset.y = base_offset_y
		return

	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		dir.y -= 1.0

	if dir != Vector2.ZERO:
		dir = dir.normalized()
		velocity = dir * speed
		_update_facing(dir)
		if not was_moving:
			anim_timer = float(next_start_idx)
			was_moving = true
			step_dist_accum = 0.0
			next_step_threshold = first_step_px
		else:
			anim_timer += delta * step_fps
		var cycle_idx := int(anim_timer) % WALK_CYCLE.size()
		var col := WALK_CYCLE[cycle_idx]
		sprite.frame = facing_row * 3 + col
		sprite.offset.y = base_offset_y - (1.0 if col != 0 else 0.0)
	else:
		if was_moving:
			next_start_idx = 2 if next_start_idx == 0 else 0
			was_moving = false
		step_dist_accum = 0.0
		next_step_threshold = first_step_px
		velocity = Vector2.ZERO
		sprite.frame = facing_row * 3
		sprite.offset.y = base_offset_y

	var prev_pos := global_position
	move_and_slide()
	var moved := global_position.distance_to(prev_pos)
	if dir != Vector2.ZERO and moved > 0.05:
		step_dist_accum += moved
		if step_dist_accum >= next_step_threshold:
			step_dist_accum -= next_step_threshold
			next_step_threshold = stride_px
			var base_pitch := 0.96 if (step_parity == 0) else 1.03
			var pitch := base_pitch + randf_range(-0.02, 0.02)
			step_parity = 1 - step_parity
			var sm: Node = get_node_or_null("/root/SoundManager")
			var step_player: AudioStreamPlayer = sm.call("play_sound_with_pitch", WOOD_STEP_SE, pitch, "Footsteps") if sm != null else null
			if step_player != null:
				step_player.volume_db = -17.0
	elif dir != Vector2.ZERO:
		# Pressed against a wall without moving: stop stride animation and reset step accumulator cleanly
		step_dist_accum = 0.0
		sprite.frame = facing_row * 3
		sprite.offset.y = base_offset_y


func _update_facing(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		facing_row = 2 if dir.x > 0.0 else 1
	else:
		facing_row = 0 if dir.y > 0.0 else 3
