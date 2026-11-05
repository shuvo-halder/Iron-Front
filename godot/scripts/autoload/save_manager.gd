class_name SaveManager
extends Node

## Handles local persistent storage for campaign progress, money, upgrades, and settings.
## Stored as JSON at user://save.json with robust default fallback and safe error recovery.

const SAVE_PATH: String = "user://save.json"

const DEFAULT_SAVE_DATA: Dictionary = {
	"unlocked_missions": [1],
	"money": 250, # War Bonds
	"upgrades": [], # e.g. ["armor_sloped", "firepower_apcr"]
	"settings": {
		"music_volume": 0.75,
		"sfx_volume": 0.85,
		"haptics_enabled": true
	}
}

var data: Dictionary = {}

func _ready() -> void:
	load_game()

func get_default_data() -> Dictionary:
	return DEFAULT_SAVE_DATA.duplicate(true)

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = get_default_data()
		save_game()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("SaveManager: Failed to open save file. Using defaults.")
		data = get_default_data()
		return

	var content := file.get_as_text()
	file.close()

	if content.strip_edges().is_empty():
		data = get_default_data()
		save_game()
		return

	var json := JSON.new()
	var parse_result := json.parse(content)
	if parse_result != OK:
		push_error("SaveManager: Save file corrupted (error %d). Restoring safe defaults." % parse_result)
		data = get_default_data()
		save_game()
		return

	var parsed = json.data
	if parsed is Dictionary:
		data = _merge_with_defaults(parsed, DEFAULT_SAVE_DATA)
	else:
		data = get_default_data()
		save_game()

	_apply_audio_settings()

func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Unable to open %s for writing." % SAVE_PATH)
		return false

	var json_string := JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return true

func _merge_with_defaults(loaded: Dictionary, defaults: Dictionary) -> Dictionary:
	var result := defaults.duplicate(true)
	for key in defaults.keys():
		if loaded.has(key):
			if defaults[key] is Dictionary and loaded[key] is Dictionary:
				result[key] = _merge_with_defaults(loaded[key], defaults[key])
			else:
				result[key] = loaded[key]
	return result

func reset_to_defaults() -> void:
	data = get_default_data()
	save_game()
	_apply_audio_settings()

# Progression API
func is_mission_unlocked(mission_idx: int) -> bool:
	var list: Array = data.get("unlocked_missions", [1])
	return list.has(mission_idx)

func unlock_mission(mission_idx: int) -> void:
	var list: Array = data.get("unlocked_missions", [1])
	if not list.has(mission_idx):
		list.append(mission_idx)
		data["unlocked_missions"] = list
		save_game()

func get_money() -> int:
	return int(data.get("money", 0))

func add_money(amount: int) -> void:
	data["money"] = get_money() + amount
	save_game()

func spend_money(amount: int) -> bool:
	if get_money() >= amount:
		data["money"] = get_money() - amount
		save_game()
		return true
	return false

func has_upgrade(upgrade_id: String) -> bool:
	var list: Array = data.get("upgrades", [])
	return list.has(upgrade_id)

func buy_upgrade(upgrade_id: String, cost: int) -> bool:
	if not has_upgrade(upgrade_id) and spend_money(cost):
		var list: Array = data.get("upgrades", [])
		list.append(upgrade_id)
		data["upgrades"] = list
		save_game()
		return true
	return false

# Settings API
func get_music_volume() -> float:
	var s: Dictionary = data.get("settings", {})
	return float(s.get("music_volume", 0.75))

func set_music_volume(volume: float) -> void:
	if not data.has("settings"):
		data["settings"] = {}
	data["settings"]["music_volume"] = clampf(volume, 0.0, 1.0)
	save_game()
	_apply_audio_settings()

func get_sfx_volume() -> float:
	var s: Dictionary = data.get("settings", {})
	return float(s.get("sfx_volume", 0.85))

func set_sfx_volume(volume: float) -> void:
	if not data.has("settings"):
		data["settings"] = {}
	data["settings"]["sfx_volume"] = clampf(volume, 0.0, 1.0)
	save_game()
	_apply_audio_settings()

func is_haptics_enabled() -> bool:
	var s: Dictionary = data.get("settings", {})
	return bool(s.get("haptics_enabled", true))

func set_haptics_enabled(enabled: bool) -> void:
	if not data.has("settings"):
		data["settings"] = {}
	data["settings"]["haptics_enabled"] = enabled
	save_game()

func _apply_audio_settings() -> void:
	var music_bus_idx := AudioServer.get_bus_index("Music")
	if music_bus_idx != -1:
		var mv := get_music_volume()
		AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(mv) if mv > 0.01 else -80.0)
		AudioServer.set_bus_mute(music_bus_idx, mv <= 0.01)

	var sfx_bus_idx := AudioServer.get_bus_index("SFX")
	if sfx_bus_idx != -1:
		var sv := get_sfx_volume()
		AudioServer.set_bus_volume_db(sfx_bus_idx, linear_to_db(sv) if sv > 0.01 else -80.0)
		AudioServer.set_bus_mute(sfx_bus_idx, sv <= 0.01)
