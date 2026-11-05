class_name BattleHUD
extends CanvasLayer

## Mobile Tactical Battle HUD for Iron Front.
## Landscape UI with touch-friendly command wheel, unit stats card, and radar minimap.

@onready var unit_card: PanelContainer = $UnitCard
@onready var unit_name_label: Label = $UnitCard/Margin/VBox/UnitName
@onready var unit_health_bar: ProgressBar = $UnitCard/Margin/VBox/HealthBar
@onready var unit_armor_label: Label = $UnitCard/Margin/VBox/ArmorStats
@onready var command_deck: HBoxContainer = $CommandDeck
@onready var fps_label: Label = $TopBar/FPSLabel
@onready var unit_count_label: Label = $TopBar/UnitCountLabel
@onready var minimap: Control = $Minimap

var tracked_unit: Unit = null

func _ready() -> void:
	unit_card.visible = false
	
	# Connect global events
	var events = get_node_or_null("/root/GameEvents")
	if events:
		events.unit_selected.connect(_on_unit_selected)
		events.selection_cleared.connect(_on_selection_cleared)
		events.units_selection_changed.connect(_on_units_selection_changed)

func _process(_delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	
	if is_instance_valid(tracked_unit) and not tracked_unit.is_dead:
		unit_health_bar.value = tracked_unit.current_health
	elif tracked_unit != null:
		_on_selection_cleared()

func _on_unit_selected(unit: CharacterBody2D) -> void:
	if unit is Unit:
		tracked_unit = unit
		unit_card.visible = true
		if unit.data:
			unit_name_label.text = unit.data.display_name
			unit_health_bar.max_value = unit.data.max_health
			unit_health_bar.value = unit.current_health
			unit_armor_label.text = "ARMOR: F:%d / S:%d / R:%d" % [int(unit.data.armor_front), int(unit.data.armor_side), int(unit.data.armor_rear)]
		else:
			unit_name_label.text = "Unit"
			unit_health_bar.value = unit.current_health

func _on_units_selection_changed(units: Array[CharacterBody2D]) -> void:
	if units.is_empty():
		_on_selection_cleared()
	elif units.size() == 1:
		_on_unit_selected(units[0])
	else:
		unit_card.visible = true
		unit_name_label.text = "Battlegroup (%d Units)" % units.size()
		var total_hp: float = 0.0
		var max_hp: float = 0.0
		for u in units:
			if u is Unit and not u.is_dead:
				total_hp += u.current_health
				max_hp += u.data.max_health if u.data else 100.0
		unit_health_bar.max_value = max_hp
		unit_health_bar.value = total_hp
		unit_armor_label.text = "Combined Arms Platoon"

func _on_selection_cleared() -> void:
	tracked_unit = null
	unit_card.visible = false

# Command Button Callbacks
func _on_move_btn_pressed() -> void:
	var sel_mgr = get_tree().root.find_child("SelectionManager", true, false)
	if sel_mgr:
		sel_mgr.current_order_mode = 0

func _on_attack_move_btn_pressed() -> void:
	var sel_mgr = get_tree().root.find_child("SelectionManager", true, false)
	if sel_mgr:
		sel_mgr.current_order_mode = 1

func _on_stop_btn_pressed() -> void:
	var sel_mgr = get_tree().root.find_child("SelectionManager", true, false)
	if sel_mgr:
		for u in sel_mgr.selected_units:
			if is_instance_valid(u) and u.has_method("order_stop"):
				u.call("order_stop")
