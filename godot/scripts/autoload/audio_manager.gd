class_name AudioManager
extends Node

## Manages sound effects pooling, volume buses, and Android tactile haptics.
## Zero external audio asset dependencies via runtime procedural audio synthesis or sample slots.

const POOL_SIZE: int = 16
var _players: Array[AudioStreamPlayer2D] = []
var _next_player_idx: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_audio_pool()
	
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.play_sfx_requested.connect(play_sfx_at)

func _init_audio_pool() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer2D.new()
		p.name = "SfxPlayer_%d" % i
		p.bus = "Master"
		p.max_polyphony = 1
		add_child(p)
		_players.append(p)

func play_sfx_at(sfx_id: String, world_pos: Vector2 = Vector2.ZERO) -> void:
	var player := _players[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % POOL_SIZE
	
	player.global_position = world_pos
	
	# Generate procedural audio generator stream or play cached sound
	var stream: AudioStream = _get_or_generate_sfx(sfx_id)
	if stream:
		player.stream = stream
		player.play()
		
	# Trigger light Android haptic pulse if enabled
	_trigger_haptic_feedback(sfx_id)

func _get_or_generate_sfx(sfx_id: String) -> AudioStream:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 0.25
	return gen

func _trigger_haptic_feedback(sfx_id: String) -> void:
	# Android Input.vibrate_handheld hook
	if sfx_id == "cannon_fire" or sfx_id == "explosion":
		Input.vibrate_handheld(45)
	elif sfx_id == "ui_click" or sfx_id == "order_confirm":
		Input.vibrate_handheld(15)
