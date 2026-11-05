class_name MainGame
extends Node2D

## Top-level battle orchestrator for Iron Front.
## Coordinates TileMap terrain, mobile input gestures, units, spatial partition, and camera.

@export var current_mission: MissionData
@export var unit_scene: PackedScene

@onready var battle_tile_map: BattleTileMap = $BattleTileMap if has_node("BattleTileMap") else null
@onready var tactical_camera: TacticalCamera = $TacticalCamera
@onready var input_manager: InputManager = $InputManager
@onready var units_container: Node2D = $Units
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
	_spawn_default_armies()

func _spawn_default_armies() -> void:
	# Allied forces (Player - Left on Road/Grass)
	_spawn_unit_at("res://resources/units/medium_tank.tres", Vector2(-320, 0), 0) # Road
	_spawn_unit_at("res://resources/units/medium_tank.tres", Vector2(-360, 60), 0)
	_spawn_unit_at("res://resources/units/heavy_tank.tres", Vector2(-420, 0), 0)
	_spawn_unit_at("res://resources/units/artillery.tres", Vector2(-520, -100), 0)
	_spawn_unit_at("res://resources/units/infantry.tres", Vector2(-260, -80), 0) # Near forest
	_spawn_unit_at("res://resources/units/infantry.tres", Vector2(-260, 80), 0)
	
	# Axis forces (Enemy - Right side)
	_spawn_unit_at("res://resources/units/medium_tank.tres", Vector2(360, 0), 1) # Road
	_spawn_unit_at("res://resources/units/medium_tank.tres", Vector2(380, 80), 1)
	_spawn_unit_at("res://resources/units/heavy_tank.tres", Vector2(440, 0), 1)
	_spawn_unit_at("res://resources/units/infantry.tres", Vector2(280, -90), 1)
	_spawn_unit_at("res://resources/units/infantry.tres", Vector2(280, 90), 1)

func _spawn_unit_at(res_path: String, pos: Vector2, faction: int) -> Unit:
	var u: Unit
	if unit_scene:
		u = unit_scene.instantiate() as Unit
	else:
		u = Unit.new()
		
	var u_data = load(res_path) as UnitData
	if u_data:
		var duplicate_data = u_data.duplicate() as UnitData
		duplicate_data.faction = faction
		u.data = duplicate_data
	u.global_position = pos
	u.faction = faction
	units_container.add_child(u)
	all_units.append(u)
	return u

func _physics_process(delta: float) -> void:
	# Apply terrain speed modifiers to units
	if battle_tile_map:
		for u in all_units:
			if is_instance_valid(u) and not u.is_dead and u.data:
				var spd_mult = battle_tile_map.get_speed_multiplier(u.global_position)
				# Dynamically adjust speed based on road boost or forest drag
				u.velocity *= spd_mult

	# Re-index spatial hash grid
	spatial_grid_update_timer -= delta
	if spatial_grid_update_timer <= 0.0:
		spatial_grid_update_timer = SPATIAL_GRID_INTERVAL
		spatial_grid.clear()
		for u in all_units:
			if is_instance_valid(u) and not u.is_dead:
				spatial_grid.insert(u)

# Gesture Callbacks from InputManager
func _on_tap_detected(world_pos: Vector2, _screen_pos: Vector2) -> void:
	var clicked_unit = _find_unit_at(world_pos)
	
	if clicked_unit != null:
		if clicked_unit.faction == 0:
			_select_single(clicked_unit)
		else:
			# Tapped enemy with units selected -> Issue Focus Target order
			if not selected_units.is_empty():
				for u in selected_units:
					if is_instance_valid(u) and not u.is_dead:
						u.order_attack_target(clicked_unit)
	else:
		# Tapped ground: check if water
		if battle_tile_map and battle_tile_map.is_position_blocked(world_pos):
			# Impassable water tile
			return
			
		if not selected_units.is_empty():
			_issue_formation_move(world_pos, false)
		else:
			_clear_selection()

func _on_long_press_detected(world_pos: Vector2, _screen_pos: Vector2) -> void:
	# Long press issues tactical ATTACK-MOVE order to point with visual confirmation
	if selected_units.is_empty():
		return
	if battle_tile_map and battle_tile_map.is_position_blocked(world_pos):
		return
		
	_issue_formation_move(world_pos, true)
	
	var pool = get_node_or_null("/root/ObjectPool")
	if pool:
		pool.spawn_explosion(world_pos, 0.45, false)

func _on_drag_box_completed(world_rect: Rect2) -> void:
	_clear_selection()
	for u in all_units:
		if is_instance_valid(u) and not u.is_dead and u.faction == 0:
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
	var count = selected_units.size()
	var cols = int(ceil(sqrt(count)))
	var spacing: float = 38.0
	
	for i in range(count):
		var u = selected_units[i]
		if not is_instance_valid(u) or u.is_dead:
			continue
			
		var row: int = i / cols
		var col: int = i % cols
		var offset := Vector2((col - cols * 0.5) * spacing, (row - cols * 0.5) * spacing)
		var final_target = dest_pos + offset
		
		# Prevent ordering units into water
		if battle_tile_map and battle_tile_map.is_position_blocked(final_target):
			final_target = dest_pos
			
		if is_attack_move:
			u.order_attack_move(final_target)
		else:
			u.order_move(final_target)

func _find_unit_at(world_pos: Vector2) -> Unit:
	for u in all_units:
		if is_instance_valid(u) and not u.is_dead:
			var r = u.data.unit_radius if u.data else 20.0
			if world_pos.distance_to(u.global_position) <= r * 1.5:
				return u
	return null

func find_nearest_enemy(from_pos: Vector2, search_radius: float, my_faction: int) -> Unit:
	var enemy_faction: int = 1 if my_faction == 0 else 0
	var candidates = spatial_grid.query_radius(from_pos, search_radius, enemy_faction)
	var closest: Unit = null
	var min_dist_sq: float = INF
	
	for cand in candidates:
		if cand is Unit and not cand.is_dead:
			var d_sq = from_pos.distance_squared_to(cand.global_position)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				closest = cand
	return closest

func get_all_allied_units() -> Array[Unit]:
	var res: Array[Unit] = []
	for u in all_units:
		if is_instance_valid(u) and not u.is_dead and u.faction == 0:
			res.append(u)
	return res

func get_all_units() -> Array[Unit]:
	return all_units

func _on_unit_killed(dead_unit: CharacterBody2D, _killer: CharacterBody2D) -> void:
	all_units.erase(dead_unit)
	selected_units.erase(dead_unit)
	_check_victory_conditions()

func _check_victory_conditions() -> void:
	var allies = 0
	var enemies = 0
	for u in all_units:
		if is_instance_valid(u) and not u.is_dead:
			if u.faction == 0: allies += 1
			elif u.faction == 1: enemies += 1
			
	var bus = get_node_or_null("/root/EventBus")
	if enemies == 0 and allies > 0:
		if bus:
			bus.mission_completed.emit(3, 100)
	elif allies == 0 and enemies > 0:
		if bus:
			bus.mission_failed.emit("Allied forces neutralized.")
