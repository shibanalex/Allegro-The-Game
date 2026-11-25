extends Node
## Audio manager for UI cues, footsteps, and BGM playback.

var _se_cursor: AudioStream
var _se_decision: AudioStream
var _se_cancel: AudioStream
var _se_buzzer: AudioStream
var _se_book: AudioStream
var _se_equip: AudioStream
var _se_blip: AudioStream
var _se_step_left: AudioStream
var _se_step_right: AudioStream
var _bgm_nocturne: AudioStream
var _bgm_rmmv: AudioStream

var _se_players: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer
var using_rmmv_bgm := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_se_cursor = load("res://assets/rmmv/audio/se/Cursor1.ogg")
	_se_decision = load("res://assets/rmmv/audio/se/Decision1.ogg")
	_se_cancel = load("res://assets/rmmv/audio/se/Cancel1.ogg")
	_se_buzzer = load("res://assets/rmmv/audio/se/Buzzer1.ogg")
	_se_book = load("res://assets/rmmv/audio/se/Book1.ogg")
	_se_equip = load("res://assets/rmmv/audio/se/Equip1.ogg")
	_se_step_left = load("res://assets/audio/se/wood_step.wav")
	_se_step_right = _se_step_left
	_se_blip = load("res://audio/se/text_blip.wav")
	_bgm_nocturne = load("res://audio/bgm/bgm_nocturne.wav")
	_bgm_rmmv = load("res://assets/rmmv/audio/bgm/Town1.ogg")

	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_se_players.append(p)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -5.0
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)


func _play_se(stream: AudioStream, pitch_min: float = 1.0, pitch_max: float = 1.0, vol_db: float = 0.0) -> void:
	if stream == null:
		return
	for p in _se_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = randf_range(pitch_min, pitch_max)
			p.volume_db = vol_db
			p.play()
			return
	var first := _se_players[0]
	first.stream = stream
	first.pitch_scale = randf_range(pitch_min, pitch_max)
	first.volume_db = vol_db
	first.play()


func play_cursor() -> void:
	_play_se(_se_cursor, 1.0, 1.0, -2.0)


func play_decision() -> void:
	_play_se(_se_decision, 1.0, 1.0, -2.0)


func play_cancel() -> void:
	_play_se(_se_cancel, 1.0, 1.0, -2.0)


func play_buzzer() -> void:
	_play_se(_se_buzzer, 1.0, 1.0, -2.0)


func play_book() -> void:
	_play_se(_se_book, 1.0, 1.0, -1.0)


func play_equip() -> void:
	_play_se(_se_equip, 1.0, 1.0, -1.0)


func play_footstep(step_index: int = 0) -> void:
	var stream := _se_step_left if (step_index % 2 == 0) else _se_step_right
	_play_se(stream, 0.94, 1.05, -10.0)


func play_text_blip(base_pitch: float = 1.0) -> void:
	_play_se(_se_blip, base_pitch * 0.97, base_pitch * 1.04, -8.0)


func play_bgm(stream: AudioStream = null) -> void:
	var target := stream
	if target == null:
		target = _bgm_rmmv if using_rmmv_bgm else _bgm_nocturne
	if target == null:
		return
	if _bgm_player.playing and _bgm_player.stream == target:
		return
	_bgm_player.stream = target
	_bgm_player.play()


func toggle_bgm_source() -> void:
	using_rmmv_bgm = not using_rmmv_bgm
	play_bgm(_bgm_rmmv if using_rmmv_bgm else _bgm_nocturne)


func stop_bgm() -> void:
	_bgm_player.stop()


func is_bgm_playing() -> bool:
	return _bgm_player.playing


func _on_bgm_finished() -> void:
	if _bgm_player.stream != null:
		_bgm_player.play()
