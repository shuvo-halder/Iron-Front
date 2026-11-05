class_name SaveManager
extends Node

## Handles local persistent storage for campaign progression, war bonds, and upgrades.
## 100% offline using user://savegame.json.

const SAVE_PATH: String = "user://savegame.json"

var profile_data: Dictionary = {
	"highest_unlocked_mission": 1,
	"war_bonds": 0,
	"mission_stars": {}, # "mission_01": 3
	"purchased_upgrades": [], # ["armor_sloped", "firepower_apcr"]
	"settings": {
		"sfx_volume": 0.85,
		"music_volume": 0.70,
		"camera_sensitivity": 1.0,
		"haptics_enabled": true
	}
}

func _ready() -> void:
	load_game()

func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Unable to open save file for writing: %s" % SAVE_PATH)
		return false
	var json_str := JSON.stringify(profile_data, "\t")
	file.store_string(json_str)
	file.close()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		save_game() # Initialize default profile
		return true
		
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
		
	var content := file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(content)
	if parsed is Dictionary:
		profile_data = parsed
		return true
	return false

func add_war_bonds(amount: int) -> void:
	profile_data["war_bonds"] = profile_data.get("war_bonds", 0) + amount
	save_game()

func unlock_next_mission(current_mission_index: int) -> void:
	var highest: int = profile_data.get("highest_unlocked_mission", 1)
	if current_mission_index + 1 > highest:
		profile_data["highest_unlocked_mission"] = min(current_mission_index + 1, 10)
		save_game()

func has_upgrade(upgrade_id: String) -> bool:
	var list: Array = profile_data.get("purchased_upgrades", [])
	return list.has(upgrade_id)

func purchase_upgrade(upgrade_id: String, cost: int) -> bool:
	var bonds: int = profile_data.get("war_bonds", 0)
	if bonds >= cost and not has_upgrade(upgrade_id):
		profile_data["war_bonds"] = bonds - cost
		var list: Array = profile_data.get("purchased_upgrades", [])
		list.append(upgrade_id)
		profile_data["purchased_upgrades"] = list
		save_game()
		return true
	return false
