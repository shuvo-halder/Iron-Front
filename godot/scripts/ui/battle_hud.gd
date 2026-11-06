class_name BattleHUD
extends CanvasLayer

## Mobile Tactical Battle HUD for Iron Front.
## Landscape UI with touch-friendly command deck, unit card, build menu, and building production queue.

# Top Bar
@onready var supply_label: Label = $TopBar/Margin/HBox/SupplyLabel
@onready var ai_wave_label: Label = $TopBar/Margin/HBox/AIWaveLabel
@onready var easy_btn: Button = $TopBar/Margin/HBox/DiffHBox/EasyBtn
@onready var med_btn: Button = $TopBar/Margin/HBox/DiffHBox/MedBtn
@onready var hard_btn: Button = $TopBar/Margin/HBox/DiffHBox/HardBtn
@onready var fps_label: Label = $TopBar/Margin/HBox/FPSLabel

# Alert Banner
@onready var alert_banner: PanelContainer = $AlertBanner
@onready var alert_label: Label = $AlertBanner/AlertLabel
var alert_display_timer: float = 0.0

# Unit Selection Card
@onready var unit_card: PanelContainer = $UnitCard
@onready var unit_name_label: Label = $UnitCard/Margin/VBox/UnitName
@onready var unit_health_bar: ProgressBar = $UnitCard/Margin/VBox/HealthBar
@onready var unit_armor_label: Label = $UnitCard/Margin/VBox/ArmorStats

# Command Deck
@onready var command_deck: HBoxContainer = $CommandDeck

# Build Catalog
@onready var build_catalog: PanelContainer = $BuildCatalog
@onready var hq_btn: Button = $BuildCatalog/Margin/VBox/Grid/HQBtn
@onready var barracks_btn: Button = $BuildCatalog/Margin/VBox/Grid/BarracksBtn
@onready var factory_btn: Button = $BuildCatalog/Margin/VBox/Grid/FactoryBtn
@onready var turret_btn: Button = $BuildCatalog/Margin/VBox/Grid/TurretBtn

# Building Production Card
@onready var building_card: PanelContainer = $BuildingProductionCard
@onready var building_title: Label = $BuildingProductionCard/Margin/VBox/BuildingTitle
@onready var queue_status_label: Label = $BuildingProductionCard/Margin/VBox/QueueStatusLabel
@onready var production_progress_bar: ProgressBar = $BuildingProductionCard/Margin/VBox/ProgressBar
@onready var production_buttons_hbox: HBoxContainer = $BuildingProductionCard/Margin/VBox/ProductionButtonsHBox

var tracked_unit: Unit = null
var tracked_building: Building = null
var is_setting_rally_point: bool = false
var current_ai_state_name: String = "GATHERING"

func _ready() -> void:
	unit_card.visible = false
	build_catalog.visible = false
	building_card.visible = false
	alert_banner.visible = false

	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.supply_changed.connect(_on_supply_changed)
		bus.unit_selected.connect(_on_unit_selected)
		bus.units_selection_changed.connect(_on_units_selection_changed)
		bus.selection_cleared.connect(_on_selection_cleared)
		bus.building_selected.connect(_on_building_selected)
		bus.building_destroyed.connect(_on_building_destroyed)
		bus.production_queue_updated.connect(_on_production_queue_updated)
		bus.enemy_wave_announced.connect(_on_enemy_wave_announced)
		bus.enemy_ai_state_changed.connect(_on_enemy_ai_state_changed)
		bus.enemy_base_alarm_triggered.connect(_on_enemy_base_alarm_triggered)

func _process(delta: float) -> void:
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()

	# Alert display timer
	if alert_display_timer > 0.0:
		alert_display_timer -= delta
		if alert_display_timer <= 0.0:
			alert_banner.visible = false

	# Live AI Wave & Difficulty sync
	var mg = get_tree().root.find_child("MainGame", true, false)
	if mg and mg.get("enemy_ai_manager") != null:
		var ai: EnemyAIManager = mg.enemy_ai_manager
		var sec := int(ceil(ai.wave_countdown))
		var diff_str := "MED"
		match ai.current_difficulty:
			EnemyAIData.Difficulty.EASY: diff_str = "EASY"
			EnemyAIData.Difficulty.MEDIUM: diff_str = "MED"
			EnemyAIData.Difficulty.HARD: diff_str = "HARD"

		var prefix := ""
		if mg.get("current_mission") != null:
			var mis: MissionData = mg.current_mission
			if mis.objective_type == MissionData.ObjectiveType.SURVIVE_TIME or mis.objective_type == MissionData.ObjectiveType.DEFEND_BUILDING:
				var time_left = maxf(0.0, mis.survive_duration_seconds - mg.mission_elapsed_time)
				prefix = "[HOLD %02d:%02d] " % [int(time_left) / 60, int(time_left) % 60]

		match ai.current_state:
			EnemyAIManager.AIState.ATTACKING:
				ai_wave_label.text = "%sWAVE %d ENGAGING! [%s]" % [prefix, ai.wave_number, diff_str]
				ai_wave_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
			EnemyAIManager.AIState.DEFENDING:
				ai_wave_label.text = "%sAXIS BASE UNDER ATTACK! [%s]" % [prefix, diff_str]
				ai_wave_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.1))
			EnemyAIManager.AIState.RETREATING:
				ai_wave_label.text = "%sAXIS RETREATING... [%s]" % [prefix, diff_str]
				ai_wave_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.35))
			_:
				ai_wave_label.text = "%sWave %d: %ds [%s]" % [prefix, ai.wave_number + 1, max(0, sec), diff_str]
				ai_wave_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))

	# Keep tracked unit health bar in sync
	if is_instance_valid(tracked_unit) and tracked_unit.current_state != Unit.State.DEAD:
		unit_health_bar.value = tracked_unit.current_hp
	elif tracked_unit != null:
		_on_selection_cleared()

	# Keep tracked building health in sync
	if is_instance_valid(tracked_building):
		var hp := int(tracked_building.current_hp)
		var max_hp := int(tracked_building.data.max_health if tracked_building.data else 1000)
		building_title.text = "%s (HP: %d/%d)" % [tracked_building.data.display_name if tracked_building.data else "Building", hp, max_hp]
	elif tracked_building != null:
		_on_close_building_card_pressed()

func _on_supply_changed(current_supply: float, rate_per_sec: float) -> void:
	supply_label.text = "Supply: %d S (+%.0f/s)" % [int(current_supply), rate_per_sec]
	_update_catalog_affordability(current_supply)

func _update_catalog_affordability(supply: float) -> void:
	hq_btn.disabled = supply < 450
	barracks_btn.disabled = supply < 150
	factory_btn.disabled = supply < 280
	turret_btn.disabled = supply < 120

# ----------------- Unit Selection Card -----------------
func _on_unit_selected(unit: CharacterBody2D) -> void:
	if unit is Unit:
		_on_close_building_card_pressed()
		tracked_unit = unit
		unit_card.visible = true
		if unit.data:
			unit_name_label.text = unit.data.display_name
			unit_health_bar.max_value = unit.data.hp
			unit_health_bar.value = unit.current_hp
			unit_armor_label.text = "ARMOR: F:%d / S:%d / R:%d" % [int(unit.data.armor_front), int(unit.data.armor_side), int(unit.data.armor_rear)]

func _on_units_selection_changed(units: Array[CharacterBody2D]) -> void:
	if units.is_empty():
		_on_selection_cleared()
	elif units.size() == 1:
		_on_unit_selected(units[0])
	else:
		_on_close_building_card_pressed()
		unit_card.visible = true
		unit_name_label.text = "Battlegroup (%d Units)" % units.size()
		var total_hp: float = 0.0
		var max_hp: float = 0.0
		for u in units:
			if u is Unit and u.current_state != Unit.State.DEAD:
				total_hp += u.current_hp
				max_hp += u.data.hp if u.data else 100.0
		unit_health_bar.max_value = max_hp
		unit_health_bar.value = total_hp
		unit_armor_label.text = "Combined Arms Platoon"

func _on_selection_cleared() -> void:
	tracked_unit = null
	unit_card.visible = false

# ----------------- Build Menu Catalog -----------------
func _on_build_menu_btn_pressed() -> void:
	build_catalog.visible = not build_catalog.visible
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		_update_catalog_affordability(gm.current_supply)

func _on_close_catalog_pressed() -> void:
	build_catalog.visible = false

func _on_build_hq_pressed() -> void:
	build_catalog.visible = false
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.building_placement_requested.emit("res://resources/buildings/hq.tres")

func _on_build_barracks_pressed() -> void:
	build_catalog.visible = false
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.building_placement_requested.emit("res://resources/buildings/barracks.tres")

func _on_build_factory_pressed() -> void:
	build_catalog.visible = false
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.building_placement_requested.emit("res://resources/buildings/factory.tres")

func _on_build_turret_pressed() -> void:
	build_catalog.visible = false
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.building_placement_requested.emit("res://resources/buildings/turret.tres")

# ----------------- Building Production Card -----------------
func _on_building_selected(building: Node2D) -> void:
	if not (building is Building):
		return

	_on_selection_cleared()
	tracked_building = building as Building
	building_card.visible = true

	# Clear previous production buttons
	for child in production_buttons_hbox.get_children():
		child.queue_free()

	if tracked_building.data:
		for path in tracked_building.data.producible_unit_paths:
			var u_data = load(path) as UnitData
			if u_data:
				var btn := Button.new()
				btn.text = "%s\n(%d S)" % [u_data.display_name, u_data.cost]
				btn.custom_minimum_size = Vector2(130, 44)
				var target_path := path
				btn.pressed.connect(func(): _on_train_unit_requested(target_path))
				production_buttons_hbox.add_child(btn)

func _on_train_unit_requested(unit_path: String) -> void:
	if is_instance_valid(tracked_building):
		tracked_building.enqueue_unit(unit_path)

func _on_production_queue_updated(building: Node2D, queue_items: Array, current_progress: float) -> void:
	if building != tracked_building:
		return

	production_progress_bar.value = current_progress * 100.0
	if queue_items.is_empty():
		queue_status_label.text = "Queue: Idle (0/5)"
	else:
		var cur_name: String = queue_items[0].get("display_name", "Unit")
		queue_status_label.text = "Training %s... (%d/5 queued)" % [cur_name, queue_items.size()]

func _on_rally_point_btn_pressed() -> void:
	is_setting_rally_point = true

func _on_close_building_card_pressed() -> void:
	if is_instance_valid(tracked_building):
		tracked_building.set_selected(false)
	tracked_building = null
	is_setting_rally_point = false
	building_card.visible = false

func _on_building_destroyed(building: Node2D) -> void:
	if building == tracked_building:
		_on_close_building_card_pressed()

# ----------------- Command Deck -----------------
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

# ----------------- Enemy AI Difficulty Controls -----------------
func _on_easy_btn_pressed() -> void:
	var mg = get_tree().root.find_child("MainGame", true, false)
	if mg and mg.get("enemy_ai_manager") != null:
		mg.enemy_ai_manager.set_difficulty(EnemyAIData.Difficulty.EASY)
		_show_alert("AI DIFFICULTY SWITCHED TO: EASY")

func _on_med_btn_pressed() -> void:
	var mg = get_tree().root.find_child("MainGame", true, false)
	if mg and mg.get("enemy_ai_manager") != null:
		mg.enemy_ai_manager.set_difficulty(EnemyAIData.Difficulty.MEDIUM)
		_show_alert("AI DIFFICULTY SWITCHED TO: MEDIUM")

func _on_hard_btn_pressed() -> void:
	var mg = get_tree().root.find_child("MainGame", true, false)
	if mg and mg.get("enemy_ai_manager") != null:
		mg.enemy_ai_manager.set_difficulty(EnemyAIData.Difficulty.HARD)
		_show_alert("AI DIFFICULTY SWITCHED TO: HARD (MAX AGGRESSION)")

func _show_alert(text: String) -> void:
	alert_label.text = text
	alert_banner.visible = true
	alert_display_timer = 3.5

func _on_enemy_wave_announced(wave_num: int, count: int, diff: String) -> void:
	_show_alert("AXIS WAVE %d LAUNCHED! (%d Units - %s)" % [wave_num, count, diff])

func _on_enemy_base_alarm_triggered(invader_count: int) -> void:
	_show_alert("AXIS BASE PERIMETER BREACHED! (%d Invaders)" % invader_count)

func _on_enemy_ai_state_changed(s_name: String) -> void:
	current_ai_state_name = s_name
