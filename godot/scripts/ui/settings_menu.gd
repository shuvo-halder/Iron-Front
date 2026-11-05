class_name SettingsMenu
extends Control

## Settings controller for Music, SFX, Haptics, and Progress Reset.

@onready var music_slider: HSlider = $Panel/VBox/MusicRow/MusicSlider if has_node("Panel/VBox/MusicRow/MusicSlider") else null
@onready var sfx_slider: HSlider = $Panel/VBox/SfxRow/SfxSlider if has_node("Panel/VBox/SfxRow/SfxSlider") else null
@onready var music_val_label: Label = $Panel/VBox/MusicRow/MusicValue if has_node("Panel/VBox/MusicRow/MusicValue") else null
@onready var sfx_val_label: Label = $Panel/VBox/SfxRow/SfxValue if has_node("Panel/VBox/SfxRow/SfxValue") else null
@onready var haptics_check: CheckButton = $Panel/VBox/HapticsRow/HapticsCheck if has_node("Panel/VBox/HapticsRow/HapticsCheck") else null
@onready var reset_confirm_dialog: ConfirmationDialog = $ResetConfirmDialog if has_node("ResetConfirmDialog") else null

func _ready() -> void:
	_load_current_values()

func _load_current_values() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr:
		return

	if music_slider:
		music_slider.value = save_mgr.get_music_volume() * 100.0
		_update_music_label(music_slider.value)
	if sfx_slider:
		sfx_slider.value = save_mgr.get_sfx_volume() * 100.0
		_update_sfx_label(sfx_slider.value)
	if haptics_check:
		haptics_check.button_pressed = save_mgr.is_haptics_enabled()

func _on_music_slider_value_changed(val: float) -> void:
	var norm_val := val / 100.0
	_update_music_label(val)
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.set_music_volume(norm_val)

func _on_sfx_slider_value_changed(val: float) -> void:
	var norm_val := val / 100.0
	_update_sfx_label(val)
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.set_sfx_volume(norm_val)

func _on_haptics_toggled(toggled_on: bool) -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.set_haptics_enabled(toggled_on)

func _update_music_label(val: float) -> void:
	if music_val_label:
		music_val_label.text = "%d%%" % int(val)

func _update_sfx_label(val: float) -> void:
	if sfx_val_label:
		sfx_val_label.text = "%d%%" % int(val)

func _on_reset_progress_pressed() -> void:
	if reset_confirm_dialog:
		reset_confirm_dialog.popup_centered()
	else:
		_confirm_reset()

func _confirm_reset() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.reset_to_defaults()
		_load_current_values()

func _on_back_pressed() -> void:
	if is_inside_tree() and get_parent() is Control and name == "SettingsModal":
		visible = false
	else:
		var trans = get_node_or_null("/root/SceneTransition")
		if trans:
			trans.change_scene("res://scenes/ui/main_menu.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
