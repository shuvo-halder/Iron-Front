class_name CampaignScreen
extends Control

## Campaign Theater Map Screen for Iron Front.
## Unlocks missions sequentially, displays briefings, objectives, star ratings,
## and allows one-tap deployment to selected battlefield operations.

const MISSION_CATALOG: Array[Dictionary] = [
	{
		"index": 1,
		"path": "res://resources/missions/mission_01_valley_vanguard.tres",
		"name": "Mission 1: Valley Vanguard",
		"tag": "[OBJECTIVE: DESTROY HQ]"
	},
	{
		"index": 2,
		"path": "res://resources/missions/mission_02_bridgehead_defense.tres",
		"name": "Mission 2: Bridgehead Stand",
		"tag": "[OBJECTIVE: DEFEND 2.5 MIN]"
	},
	{
		"index": 3,
		"path": "res://resources/missions/mission_03_iron_sweep.tres",
		"name": "Mission 3: Iron Sweep",
		"tag": "[OBJECTIVE: ELIMINATE ALL]"
	}
]

var selected_mission_data: MissionData = null
var selected_mission_path: String = ""

# Node references
@onready var war_bonds_label: Label = $Header/Margin/HBox/WarBondsLabel
@onready var mission_list_container: VBoxContainer = $Body/HBox/LeftColumn/Scroll/MissionList
@onready var detail_panel: PanelContainer = $Body/HBox/RightColumn/DetailPanel
@onready var detail_title: Label = $Body/HBox/RightColumn/DetailPanel/Margin/VBox/TitleLabel
@onready var detail_tag: Label = $Body/HBox/RightColumn/DetailPanel/Margin/VBox/TagLabel
@onready var detail_briefing: Label = $Body/HBox/RightColumn/DetailPanel/Margin/VBox/BriefingLabel
@onready var detail_objective: Label = $Body/HBox/RightColumn/DetailPanel/Margin/VBox/ObjectiveLabel
@onready var detail_stars_criteria: Label = $Body/HBox/RightColumn/DetailPanel/Margin/VBox/StarsCriteriaLabel
@onready var detail_reward: Label = $Body/HBox/RightColumn/DetailPanel/Margin/VBox/RewardLabel
@onready var deploy_button: Button = $Body/HBox/RightColumn/DetailPanel/Margin/VBox/DeployBtn

func _ready() -> void:
	_update_header()
	_populate_mission_nodes()

	# Select the highest unlocked mission by default
	var highest_idx := 1
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		for entry in MISSION_CATALOG:
			if save_mgr.is_mission_unlocked(entry.index):
				highest_idx = entry.index
	_select_mission_by_index(highest_idx)

func _update_header() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and war_bonds_label:
		war_bonds_label.text = "WAR BONDS: %d WB" % save_mgr.get_money()

func _populate_mission_nodes() -> void:
	for child in mission_list_container.get_children():
		child.queue_free()

	var save_mgr = get_node_or_null("/root/SaveManager")

	for entry in MISSION_CATALOG:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(340, 68)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var is_unlocked := true
		var stars := 0
		if save_mgr:
			is_unlocked = save_mgr.is_mission_unlocked(entry.index)
			stars = save_mgr.get_mission_stars(entry.index)

		btn.disabled = not is_unlocked

		var stars_str := ""
		if is_unlocked:
			for s in range(3):
				stars_str += "★" if s < stars else "☆"

		if is_unlocked:
			btn.text = "  %s\n  Stars: %s   %s" % [entry.name, stars_str, entry.tag]
		else:
			btn.text = "  %s\n  [LOCKED - Complete Previous Mission]" % entry.name

		var target_idx: int = entry.index
		btn.pressed.connect(func(): _select_mission_by_index(target_idx))
		mission_list_container.add_child(btn)

func _select_mission_by_index(idx: int) -> void:
	for entry in MISSION_CATALOG:
		if entry.index == idx:
			selected_mission_path = entry.path
			if ResourceLoader.exists(selected_mission_path):
				selected_mission_data = load(selected_mission_path) as MissionData
			break

	_display_mission_details()

func _display_mission_details() -> void:
	if not selected_mission_data:
		return

	detail_title.text = selected_mission_data.title
	detail_briefing.text = selected_mission_data.briefing
	detail_objective.text = "OBJECTIVE: %s" % selected_mission_data.objective_description

	match selected_mission_data.objective_type:
		MissionData.ObjectiveType.DESTROY_HQ:
			detail_tag.text = "[MISSION TYPE: STRATEGIC ASSAULT]"
		MissionData.ObjectiveType.SURVIVE_TIME:
			detail_tag.text = "[MISSION TYPE: SURVIVAL STAND]"
		MissionData.ObjectiveType.DEFEND_BUILDING:
			detail_tag.text = "[MISSION TYPE: BASE DEFENSE]"
		MissionData.ObjectiveType.ELIMINATE_ALL:
			detail_tag.text = "[MISSION TYPE: TOTAL SECTOR SWEEP]"

	detail_stars_criteria.text = "★ 1-Star: Complete Primary Objective\n★ 2-Star: Complete under %ds Par Time\n★ 3-Star: Suffer <= %d Casualties" % [
		int(selected_mission_data.par_time_seconds),
		selected_mission_data.max_allowed_casualties_3_star
	]

	detail_reward.text = "COMPLETION REWARD: +%d WAR BONDS" % selected_mission_data.reward_money

	var save_mgr = get_node_or_null("/root/SaveManager")
	var is_unlocked := true
	if save_mgr:
		is_unlocked = save_mgr.is_mission_unlocked(selected_mission_data.mission_index)

	deploy_button.disabled = not is_unlocked
	deploy_button.text = "DEPLOY TO BATTLEFIELD" if is_unlocked else "MISSION LOCKED"

func _on_deploy_btn_pressed() -> void:
	if selected_mission_data and not selected_mission_path.is_empty():
		_play_ui_click()
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("load_mission"):
			gm.load_mission(selected_mission_path)
		else:
			get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_back_btn_pressed() -> void:
	_play_ui_click()
	var trans = get_node_or_null("/root/SceneTransition")
	if trans:
		trans.change_scene("res://scenes/ui/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _play_ui_click() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx_at("ui_click")
