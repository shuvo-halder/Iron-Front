class_name MainMenu
extends Control

## Main Menu controller for Iron Front.
## Handles Play (Quick Battle), Campaign (Mission Select), Upgrades, Settings, and Quit.

@onready var war_bonds_label: Label = $Header/WarBondsLabel if has_node("Header/WarBondsLabel") else null
@onready var settings_modal: Control = $SettingsModal if has_node("SettingsModal") else null

func _ready() -> void:
	_update_profile_display()
	if settings_modal:
		settings_modal.visible = false

func _update_profile_display() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and war_bonds_label:
		war_bonds_label.text = "WAR BONDS: %d WB" % save_mgr.get_money()

func _on_play_button_pressed() -> void:
	_play_ui_click()
	var trans = get_node_or_null("/root/SceneTransition")
	if trans:
		trans.change_scene("res://scenes/main_game.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_campaign_button_pressed() -> void:
	_play_ui_click()
	var trans = get_node_or_null("/root/SceneTransition")
	if trans:
		trans.change_scene("res://scenes/ui/mission_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/mission_select.tscn")

func _on_upgrades_button_pressed() -> void:
	_play_ui_click()
	var trans = get_node_or_null("/root/SceneTransition")
	if trans:
		trans.change_scene("res://scenes/ui/upgrade_shop.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/upgrade_shop.tscn")

func _on_settings_button_pressed() -> void:
	_play_ui_click()
	if settings_modal:
		settings_modal.visible = true
	else:
		var trans = get_node_or_null("/root/SceneTransition")
		if trans:
			trans.change_scene("res://scenes/ui/settings_menu.tscn")

func _on_quit_button_pressed() -> void:
	_play_ui_click()
	get_tree().quit()

func _play_ui_click() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		audio.play_sfx_at("ui_click")
