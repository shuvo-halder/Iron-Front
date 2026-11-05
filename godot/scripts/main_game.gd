class_name MainGame
extends Node2D

## Top-level game orchestrator for Iron Front.
## Coordinates units, spatial partition grid, mission victory conditions, and camera.

@export var current_mission: MissionData
@export var unit_scene: PackedScene

@onready var units_container: Node2D = $Units
@onready var tactical_camera: TacticalCamera = $TacticalCamera
@onready var selection_manager: SelectionManager = $SelectionManager
@onready var battle_hud: BattleHUD = $BattleHUD

var spatial_grid: SpatialGrid
var all_units: Array[Unit] = []
var spatial_grid_update_timer: float = 0.0
const SPATIAL_GRID_INTERVAL: float = 0.05 # 20Hz spatial re-binning for 100 units

func _ready() -> void:
	spatial_grid = SpatialGrid.new(128.0)
	_setup_mission()
	
	var events = get_node_or_null("/root/GameEvents")
	if events:
		events.unit_killed.connect(_on_unit_killed)

func _setup_mission() -> void:
	# Spawn sample tactical battle units if not pre-placed
	_spawn_default_armies()

func _spawn_default_armies() -> void:
	# Allied forces (Player - Green)
	_spawn_unit_at("res://resources/units/medium_tank.tres", Vector2(-300, -80), 0)
	_spawn_unit_at("res://resources/units/medium_tank.tres", Vector2(-300, 80), 0)
	_spawn_unit_at("res://resources/units/heavy_tank.tres", Vector2(-360, 0), 0)
	_spawn_unit_at("res://resources/units/artillery.tres", Vector2(-460, 0), 0)
	_spawn_unit_at("res://resources/units/infantry.tres", Vector2(-220, -140), 0)
	_spawn_unit_at("res://resources/units/infantry.tres", Vector2(-220, 140), 0)
	
	# Axis forces (Enemy - Red)
	_spawn_unit_at("res://resources/units/medium_tank.tres", Vector2(300, -100), 1)
	_spawn_unit_at("res://resources/units/medium_tank.tres", Vector2(300, 100), 1)
	_spawn_unit_at("res://resources/units/heavy_tank.tres", Vector2(380, 0), 1)
	_spawn_unit_at("res://resources/units/infantry.tres", Vector2(200, -50), 1)
	_spawn_unit_at("res://resources/units/infantry.tres", Vector2(200, 50), 1)

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
	# Update spatial grid at fixed tick rate to save mobile CPU
	spatial_grid_update_timer -= delta
	if spatial_grid_update_timer <= 0.0:
		spatial_grid_update_timer = SPATIAL_GRID_INTERVAL
		spatial_grid.clear()
		for u in all_units:
			if is_instance_valid(u) and not u.is_dead:
				spatial_grid.insert(u)

func find_nearest_enemy(from_pos: Vector2, search_radius: float, my_faction: int) -> Unit:
	var enemy_faction: int = 1 if my_faction == 0 else 0
	var candidates: Array[CharacterBody2D] = spatial_grid.query_radius(from_pos, search_radius, enemy_faction)
	
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
	var result: Array[Unit] = []
	for u in all_units:
		if is_instance_valid(u) and not u.is_dead and u.faction == 0:
			result.append(u)
	return result

func get_all_units() -> Array[Unit]:
	return all_units

func _on_unit_killed(dead_unit: CharacterBody2D, _killer: CharacterBody2D) -> void:
	all_units.erase(dead_unit)
	_check_victory_conditions()

func _check_victory_conditions() -> void:
	var allies = 0
	var enemies = 0
	for u in all_units:
		if is_instance_valid(u) and not u.is_dead:
			if u.faction == 0: allies += 1
			elif u.faction == 1: enemies += 1
			
	if enemies == 0 and allies > 0:
		var events = get_node_or_null("/root/GameEvents")
		if events:
			events.battle_ended.emit(true)
	elif allies == 0 and enemies > 0:
		var events = get_node_or_null("/root/GameEvents")
		if events:
			events.battle_ended.emit(false)
