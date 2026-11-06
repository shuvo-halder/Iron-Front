class_name MissionCompleteModal
extends Control

## Mission Complete / Failed summary modal for Iron Front.
## Shows star ratings (1-3 stars), combat statistics, war bond reward,
## and next mission / replay / campaign map navigation.

signal next_mission_requested()
signal replay_mission_requested()
signal campaign_map_requested()

@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/Margin/VBox/SubtitleLabel
@onready var stars_container: HBoxContainer = $Panel/Margin/VBox/StarsContainer
@onready var star_1: Label = $Panel/Margin/VBox/StarsContainer/Star1
@onready var star_2: Label = $Panel/Margin/VBox/StarsContainer/Star2
@onready var star_3: Label = $Panel/Margin/VBox/StarsContainer/Star3
@onready var stats_label: Label = $Panel/Margin/VBox/StatsLabel
@onready var reward_label: Label = $Panel/Margin/VBox/RewardLabel
@onready var next_btn: Button = $Panel/Margin/VBox/ButtonHBox/NextBtn
@onready var replay_btn: Button = $Panel/Margin/VBox/ButtonHBox/ReplayBtn
@onready var map_btn: Button = $Panel/Margin/VBox/ButtonHBox/MapBtn

func _ready() -> void:
	visible = false

func show_results(
	won: bool,
	mission: MissionData,
	time_elapsed: float,
	casualties: int,
	enemies_destroyed: int,
	stars: int,
	reward_earned: int
) -> void:
	visible = true

	if won:
		title_label.text = "MISSION ACCOMPLISHED"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		subtitle_label.text = mission.title if mission else "Operation Successful"
		stars_container.visible = true

		# Update stars visuals
		star_1.text = "★" if stars >= 1 else "☆"
		star_1.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if stars >= 1 else Color(0.4, 0.4, 0.4))

		star_2.text = "★" if stars >= 2 else "☆"
		star_2.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if stars >= 2 else Color(0.4, 0.4, 0.4))

		star_3.text = "★" if stars >= 3 else "☆"
		star_3.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if stars >= 3 else Color(0.4, 0.4, 0.4))

		reward_label.text = "REWARD: +%d WAR BONDS" % reward_earned
		reward_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		next_btn.visible = true
	else:
		title_label.text = "MISSION FAILED"
		title_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
		subtitle_label.text = "Frontline Compromised - Tactical Defeat"
		stars_container.visible = false
		reward_label.text = "NO WAR BONDS AWARDED"
		reward_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4))
		next_btn.visible = false

	var minutes := int(time_elapsed) / 60
	var seconds := int(time_elapsed) % 60
	stats_label.text = "TIME: %02d:%02d  |  ENEMIES NEUTRALIZED: %d  |  ALLIED LOSSES: %d" % [
		minutes, seconds, enemies_destroyed, casualties
	]

func _on_next_btn_pressed() -> void:
	next_mission_requested.emit()

func _on_replay_btn_pressed() -> void:
	replay_mission_requested.emit()

func _on_map_btn_pressed() -> void:
	campaign_map_requested.emit()
