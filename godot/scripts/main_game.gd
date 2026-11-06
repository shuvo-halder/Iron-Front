class_name MainGame
extends Node2D

## Top-level battle orchestrator for Iron Front.
## Coordinates TileMap terrain, mobile input gestures, units, buildings, economy, and camera.

@export var current_mission: MissionData
@export var unit_scene: PackedScene = preload("res://scenes/entities/unit.tscn")
@export var building_scene: PackedScene = preload("res://scenes/entities/building.tscn")
@export var supply_crate_scene: PackedScene = preload("res://scenes/entities/supply_crate.tscn")

@onready var battle_tile_map: BattleTileMap = $BattleTileMap if has_node("BattleTileMap") else null
@onready var tactical_camera: TacticalCamera = $TacticalCamera
@onready var input_manager: InputManager = $InputManager
@onready var units_container: Node2D = $Units
@onready var buildings_container: Node2D = $Buildings if has_node("Buildings") else null
@onready var crates_container: Node2D = $SupplyCrates if has_node("SupplyCrates") else null
@onready var build_manager: BuildManager = $BuildManager if has_node("BuildManager") else null
@onready var battle_hud: BattleHUD = $BattleHUD

var spatial_grid: SpatialGrid
var all_units: Array[Unit] = []
var selected_units: Array[Unit] = []
var spatial_grid_update_timer: float = 0.0
const SPATIAL_GRID_INTERVAL: float = 0.05

func _ready() -> void:
	spatial_grid = SpatialGrid.new(128.0)

	# Clamp camera to tilemap bounds
	if battle_tile_map:
		tactical_camera.set_map_bounds(battle_tile_map.get_map_world_bounds())

	# Wire BuildManager
	if build_manager:
		build_manager.setup(self, battle_tile_map)

	# Wire InputManager gestures
	if input_manager:
		input_manager.camera = tactical_camera
		input_manager.tap_detected.connect(_on_tap_detected)
		input_manager.long_press_detected.connect(_on_long_press_detected)
		input_manager.drag_box_completed.connect(_on_drag_box_completed)

	var events = get_node_or_null("/root/EventBus")
	if events:
		events.unit_killed.connect(_on_unit_killed)

	_setup_mission()

func _setup_mission() -> void:
	_spawn_base_infrastructure()
	_spawn_collectible_supply_crates()
	_spawn_skirmish_forces()

func _spawn_base_infrastructure() -> void:
	if not buildings_container:
		return

	# Allied Headquarters (West Base)
	_spawn_building_at("res://resources/buildings/hq.tres", Vector2(-750, 0), 0)
	# Allied Barracks
	_spawn_building_at("res://resources/buildings/barracks.tres", Vector2(-750, -130), 0)
	# Allied Defense Turret near the bridge approach
	_spawn_building_at("res://resources/buildings/turret.tres", Vector2(-360, 0), 0)

	# Axis Headquarters (East Base)
	_spawn_building_at("res://resources/buildings/hq.tres", Vector2(750, 0), 1)
	# Axis Factory
	_spawn_building_at("res://resources/buildings/factory.tres", Vector2(750, 130), 1)
	# Axis Defense Turret near east bridge approach
	_spawn_building_at("res://resources/buildings/turret.tres", Vector2(360, 0), 1)

func _spawn_building_at(res_path: String, pos: Vector2, faction: int) -> Building:
	var b_node: Building = building_scene.instantiate() as Building
	var b_data = load(res_path) as BuildingData
	if b_data:
		var dup = b_data.duplicate() as BuildingData
		dup.faction = faction
		b_node.data = dup
	b_node.global_position = pos
	b_node.is_under_construction = false
	buildings_container.add_child(b_node)
	return b_node

func _spawn_collectible_supply_crates() -> void:
	if not crates_container:
		return

	var crate_positions := [
		Vector2(-180, -220),
		Vector2(180, -220),
		Vector2(-180, 220),
		Vector2(180, 220),
		Vector2(0, 0),       # High-value crate on the central bridge!
		Vector2(-450, 240),
		Vector2(450, -240)
	]

	for pos in crate_positions:
		var crate: SupplyCrate = supply_crate_scene.instantiate() as SupplyCrate
		crate.global_position = pos
		crates_container.add_child(crate)

func _spawn_skirmish_forces() -> void:
	# 15 Allied Starting Units
	var allied_classes = [
		"res://resources/units/attack_helicopter.tres",
		"res://resources/units/medium_tank.tres",
		"res://resources/units/scout_car.tres",
		"res://resources/units/rifle_squad.tres",
		"res://resources/units/anti_tank_team.tres"
	]
	for i in range(15):
		var res_path: String = allied_classes[i % allied_classes.size()]
		var col: int = i % 3
		var row: int = i / 3
		var pos := Vector2(-540.0 + col * 55.0, -120.0 + row * 60.0)
		_spawn_unit_at(res_path, pos, 0)

	# 15 Axis Starting Units
	var axis_classes = [
		"res://resources/units/attack_helicopter.tres",
		"res://resources/units/medium_tank.tres",
		"res://resources/units/scout_car.tres",
		"res://resources/units/rifle_squad.tres",
		"res://resources/units/anti_tank_team.tres"
	]
	for i in range(15):
		var res_path: String = axis_classes[i % axis_classes.size()]
		var col: int = i % 3
		var row: int = i / 3
		var pos := Vector2(400.0 + col * 55.0, -120.0 + row * 60.0)
		_spawn_unit_at(res_path, pos, 1)

func _spawn_unit_at(res_path: String, pos: Vector2, faction: int) -> Unit:
	var u: Unit
	if unit_scene:
		u = unit_scene.instantiate() as Unit
	else:
		u = Unit.new()

	var u_data = load(res_path) as UnitData
	if u_data:
		var duplicate_data = u_data.duplicate() as UnitData
		duplicate_data.team = faction
		u.data = duplicate_data
	u.global_position = pos
	if faction == 1:
		u.rotation = PI
	units_container.add_child(u)
	all_units.append(u)
	return u

func _physics_process(delta: float) -> void:
	# Update building placement ghost
	if build_manager and build_manager.is_building_mode:
		var mouse_world := get_global_mouse_position()
		build_manager.update_ghost_position(mouse_world)

	# Terrain speed modifiers
	if battle_tile_map:
		for u in all_units:
			if is_instance_valid(u) and u.current_state != Unit.State.DEAD and u.data:
				var spd_mult = battle_tile_map.get_speed_multiplier(u.global_position)
				u.velocity *= spd_mult

	# Re-index spatial grid
	spatial_grid_update_timer -= delta
	if spatial_grid_update_timer <= 0.0:
		spatial_grid_update_timer = SPATIAL_GRID_INTERVAL
		spatial_grid.clear()
		for u in all_units:
			if is_instance_valid(u) and u.current_state != Unit.State.DEAD:
				spatial_grid.insert(u)

# Gesture Callbacks from InputManager
func _on_tap_detected(world_pos: Vector2, _screen_pos: Vector2) -> void:
	# 1. If currently in Building Placement mode, attempt placement
	if build_manager and build_manager.is_building_mode:
		build_manager.update_ghost_position(world_pos)
		if build_manager.try_place_building():
			_spawn_order_marker(world_pos, false)
		return

	# 2. If setting a Rally Point for selected building
	if battle_hud and battle_hud.is_setting_rally_point and is_instance_valid(battle_hud.tracked_building):
		battle_hud.tracked_building.set_rally_point(world_pos)
		battle_hud.is_setting_rally_point = false
		_spawn_order_marker(world_pos, false)
		return

	# 3. Check if tapped on a Building
	var clicked_building := _find_building_at(world_pos)
	if clicked_building != null:
		if clicked_building.data and clicked_building.data.faction == 0:
			_clear_selection()
			clicked_building.set_selected(true)
			return
		else:
			# Enemy building tapped with units selected -> Issue Focus Target order
			if not selected_units.is_empty():
				_spawn_order_marker(clicked_building.global_position, true)
				for u in selected_units:
					if is_instance_valid(u) and u.current_state != Unit.State.DEAD:
						u.order_attack_move(clicked_building.global_position)
				return

	# 4. Check if tapped on a Unit
	var clicked_unit := _find_unit_at(world_pos)
	if clicked_unit != null:
		if clicked_unit.data and clicked_unit.data.team == 0:
			_select_single(clicked_unit)
		else:
			# Tapped enemy unit with units selected -> Issue Focus Target order
			if not selected_units.is_empty():
				_spawn_order_marker(clicked_unit.global_position, true)
				for u in selected_units:
					if is_instance_valid(u) and u.current_state != Unit.State.DEAD:
						u.order_attack_target(clicked_unit)
	else:
		# Tapped ground
		if battle_tile_map and battle_tile_map.is_position_blocked(world_pos):
			return # Blocked river water

		if not selected_units.is_empty():
			_spawn_order_marker(world_pos, false)
			_issue_formation_move(world_pos, false)
		else:
			_clear_selection()
			if battle_hud:
				battle_hud._on_close_building_card_pressed()

func _on_long_press_detected(world_pos: Vector2, _screen_pos: Vector2) -> void:
	if selected_units.is_empty():
		return
	if battle_tile_map and battle_tile_map.is_position_blocked(world_pos):
		return
	_spawn_order_marker(world_pos, true)
	_issue_formation_move(world_pos, true)

func _spawn_order_marker(pos: Vector2, is_attack: bool) -> void:
	var marker := OrderMarker.new()
	marker.setup_marker(pos, OrderMarker.MarkerType.ATTACK if is_attack else OrderMarker.MarkerType.MOVE)
	add_child(marker)

func _on_drag_box_completed(world_rect: Rect2) -> void:
	_clear_selection()
	for u in all_units:
		if is_instance_valid(u) and u.current_state != Unit.State.DEAD and u.data and u.data.team == 0:
			if world_rect.has_point(u.global_position):
				selected_units.append(u)
				u.set_selected(true)

	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.units_selection_changed.emit(selected_units)

func _select_single(u: Unit) -> void:
	_clear_selection()
	selected_units.append(u)
	u.set_selected(true)

	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.unit_selected.emit(u)
		bus.units_selection_changed.emit(selected_units)

func _clear_selection() -> void:
	for u in selected_units:
		if is_instance_valid(u):
			u.set_selected(false)
	selected_units.clear()

	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.selection_cleared.emit()

func _issue_formation_move(dest_pos: Vector2, is_attack_move: bool) -> void:
	var count := selected_units.size()
	if count == 0:
		return

	var cols := int(ceil(sqrt(count * 1.5)))
	var rows := int(ceil(float(count) / float(cols)))
	var spacing := 44.0

	for i in range(count):
		var u := selected_units[i]
		if not is_instance_valid(u) or u.current_state == Unit.State.DEAD:
			continue

		var col := i % cols
		var row := i / cols
		var offset := Vector2((col - cols * 0.5) * spacing, (row - rows * 0.5) * spacing)
		var final_target := dest_pos + offset

		if battle_tile_map and battle_tile_map.is_position_blocked(final_target):
			final_target = dest_pos

		if is_attack_move:
			u.order_attack_move(final_target)
		else:
			u.order_move(final_target)

func _find_unit_at(world_pos: Vector2) -> Unit:
	for u in all_units:
		if is_instance_valid(u) and u.current_state != Unit.State.DEAD:
			var r = u.data.unit_radius if u.data else 20.0
			if world_pos.distance_to(u.global_position) <= r * 1.5:
				return u
	return null

func _find_building_at(world_pos: Vector2) -> Building:
	if not buildings_container:
		return null
	for child in buildings_container.get_children():
		if child is Building and is_instance_valid(child):
			var r = child.data.footprint_radius if child.data else 45.0
			if world_pos.distance_to(child.global_position) <= r * 1.1:
				return child
	return null

func _on_unit_killed(dead_unit: CharacterBody2D, _killer: CharacterBody2D) -> void:
	all_units.erase(dead_unit)
	selected_units.erase(dead_unit)
	_check_victory_conditions()

func _check_victory_conditions() -> void:
	var allies = 0
	var enemies = 0
	for u in all_units:
		if is_instance_valid(u) and u.current_state != Unit.State.DEAD:
			if u.data and u.data.team == 0: allies += 1
			elif u.data and u.data.team == 1: enemies += 1

	var bus = get_node_or_null("/root/EventBus")
	if enemies == 0 and allies > 0:
		if bus:
			bus.mission_completed.emit(3, 100)
	elif allies == 0 and enemies > 0:
		if bus:
			bus.mission_failed.emit("Allied forces neutralized.")
