class_name EnemyAIManager
extends Node

## Enemy AI Manager for Iron Front with 3 difficulty levels.
## Executes data-driven build orders, wave forming, 4-tier target priority,
## outnumbered retreats, and base defense alarms.
## Updates strictly on a 0.5s decision cycle (2 Hz) for optimal mobile 60 FPS.

signal ai_state_changed(new_state: int, state_name: String)
signal wave_launched(wave_number: int, unit_count: int)
signal retreat_ordered(unit_count: int)
signal base_defense_triggered(invader_count: int)
signal enemy_supply_updated(current: float)

enum AIState {
	GATHERING,   # Producing units and assembling at staging area
	ATTACKING,   # Advancing and engaging prioritized player targets
	RETREATING,  # Disengaging when outnumbered or critically damaged
	DEFENDING    # Base perimeter breached; intercepting invaders
}

const AI_TICK_INTERVAL: float = 0.5 # 2 Hz decision cycle

@export var ai_data: EnemyAIData
@export var enabled: bool = true

var current_state: AIState = AIState.GATHERING
var current_difficulty: EnemyAIData.Difficulty = EnemyAIData.Difficulty.MEDIUM

# Live Economy
var ai_supply: float = 450.0
var build_order_index: int = 0

# Wave management
var wave_number: int = 0
var wave_countdown: float = 30.0
var staging_timer: float = 0.0

# Units tracking
var staging_units: Array[Unit] = []
var active_wave_units: Array[Unit] = []
var base_defenders: Array[Unit] = []

# Base Defense Alarm
var base_alert_timer: float = 0.0
const BASE_ALERT_DURATION: float = 12.0

# 0.5s Decision accumulator
var _tick_accumulator: float = 0.0

func _ready() -> void:
	if not ai_data:
		ai_data = load("res://resources/ai/medium_ai.tres") as EnemyAIData
	
	if ai_data:
		_apply_ai_data(ai_data)

	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.building_damaged.connect(_on_building_damaged)
		bus.unit_killed.connect(_on_unit_killed)

func _apply_ai_data(data: EnemyAIData) -> void:
	ai_data = data
	current_difficulty = data.difficulty
	ai_supply = data.starting_supply
	wave_countdown = data.wave_interval_seconds
	build_order_index = 0
	enemy_supply_updated.emit(ai_supply)

func set_difficulty(diff: EnemyAIData.Difficulty) -> void:
	var path := ""
	match diff:
		EnemyAIData.Difficulty.EASY:
			path = "res://resources/ai/easy_ai.tres"
		EnemyAIData.Difficulty.MEDIUM:
			path = "res://resources/ai/medium_ai.tres"
		EnemyAIData.Difficulty.HARD:
			path = "res://resources/ai/hard_ai.tres"

	if ResourceLoader.exists(path):
		var res = load(path) as EnemyAIData
		if res:
			_apply_ai_data(res)
			_change_state(AIState.GATHERING)

## Physics process accumulates passive income & runs the 0.5s AI tick.
## No expensive target searches or path calculations are performed per-frame.
func _physics_process(delta: float) -> void:
	if not enabled or not ai_data:
		return

	# Smooth passive income accumulation
	var income_rate: float = ai_data.passive_supply_rate * ai_data.supply_income_multiplier
	ai_supply += income_rate * delta

	# Base alert timer countdown
	if base_alert_timer > 0.0:
		base_alert_timer -= delta

	# Wave timer countdown
	if current_state == AIState.GATHERING:
		wave_countdown -= delta
		staging_timer += delta

	# 0.5s AI Decision Cycle
	_tick_accumulator += delta
	if _tick_accumulator >= AI_TICK_INTERVAL:
		_tick_accumulator -= AI_TICK_INTERVAL
		_on_ai_tick()

## Core 2 Hz AI loop
func _on_ai_tick() -> void:
	_cleanup_dead_units()
	enemy_supply_updated.emit(ai_supply)

	# 1. Base Defense Check (Highest Priority)
	var invaders := _get_player_units_in_base_perimeter()
	if not invaders.is_empty() or base_alert_timer > 0.0:
		if current_state != AIState.DEFENDING:
			_trigger_base_defense(invaders)
	elif current_state == AIState.DEFENDING:
		# Invaders cleared! Resume normal operations
		_change_state(AIState.GATHERING)

	# 2. Economy Management & Unit Production
	_manage_production()

	# 3. Check for Nearby Unclaimed Crates
	_scout_nearby_crates()

	# 4. Outnumbered & Damage Retreat Check
	_check_retreat_conditions()

	# 5. Wave Progression & Staging
	_manage_waves()

	# 6. Issue Prioritized Combat Orders
	if current_state == AIState.ATTACKING:
		_issue_attack_wave_orders()
	elif current_state == AIState.DEFENDING:
		_issue_defense_orders(invaders)

## Production: Steps through build order and enqueues units at Axis facilities
func _manage_production() -> void:
	if not ai_data or ai_data.build_order.is_empty():
		return

	var unit_path: String = ai_data.build_order[build_order_index]
	if not ResourceLoader.exists(unit_path):
		build_order_index = (build_order_index + 1) % ai_data.build_order.size()
		return

	var u_data = load(unit_path) as UnitData
	if not u_data:
		return

	if ai_supply >= u_data.cost:
		var facility := _find_suitable_facility(u_data)
		if facility != null:
			if facility.has_method("enqueue_unit_ai") and facility.enqueue_unit_ai(unit_path):
				ai_supply -= u_data.cost
				facility.set_rally_point(ai_data.staging_area)
				build_order_index = (build_order_index + 1) % ai_data.build_order.size()

func _find_suitable_facility(u_data: UnitData) -> Building:
	var buildings := get_tree().get_nodes_in_group("buildings")
	var target_type := BuildingData.BuildingType.FACTORY

	if u_data.armor_type == UnitData.ArmorType.INFANTRY:
		target_type = BuildingData.BuildingType.BARRACKS
	elif u_data.unit_class == UnitData.UnitClass.COMBAT_ENGINEER:
		target_type = BuildingData.BuildingType.HQ

	var best_building: Building = null
	var min_queue_size := 6

	for node in buildings:
		if node is Building and node.data and node.data.faction == 1 and not node.is_under_construction:
			if node.data.building_type == target_type or node.data.building_type == BuildingData.BuildingType.HQ:
				if node.production_queue.size() < min_queue_size:
					min_queue_size = node.production_queue.size()
					best_building = node

	return best_building

## Sends scout units or infantry to claim open supply crates on enemy half of the map
func _scout_nearby_crates() -> void:
	var crates := get_tree().get_nodes_in_group("crates")
	if crates.is_empty():
		return

	for c_node in crates:
		if is_instance_valid(c_node) and c_node.global_position.x > 0.0: # East half
			# Find an idle axis unit to grab it
			var idle_unit := _find_closest_idle_axis_unit(c_node.global_position)
			if idle_unit != null:
				idle_unit.order_move(c_node.global_position)

## Wave formation logic
func _manage_waves() -> void:
	# Keep staging units updated
	_gather_idle_axis_units()

	if current_state == AIState.GATHERING:
		var ready_to_launch := false
		if wave_countdown <= 0.0 and staging_units.size() >= ai_data.min_wave_size:
			ready_to_launch = true
		elif staging_timer >= ai_data.max_staging_time and staging_units.size() >= 2:
			ready_to_launch = true

		if ready_to_launch:
			_launch_wave()

	elif current_state == AIState.ATTACKING:
		# Check if wave has been neutralized
		if active_wave_units.is_empty():
			_change_state(AIState.GATHERING)
			wave_countdown = ai_data.wave_interval_seconds
			staging_timer = 0.0

func _launch_wave() -> void:
	wave_number += 1
	active_wave_units = staging_units.duplicate()
	staging_units.clear()
	staging_timer = 0.0
	wave_countdown = ai_data.wave_interval_seconds

	_change_state(AIState.ATTACKING)
	wave_launched.emit(wave_number, active_wave_units.size())

	var bus = get_node_or_null("/root/EventBus")
	if bus:
		var diff_name := "Medium"
		match current_difficulty:
			EnemyAIData.Difficulty.EASY: diff_name = "Easy"
			EnemyAIData.Difficulty.MEDIUM: diff_name = "Medium"
			EnemyAIData.Difficulty.HARD: diff_name = "Hard"
		bus.enemy_wave_announced.emit(wave_number, active_wave_units.size(), diff_name)

## Outnumbered & Tactical Retreat Evaluation
func _check_retreat_conditions() -> void:
	if active_wave_units.is_empty():
		return

	var units_retreated := 0
	var units_to_remove: Array[Unit] = []

	for u in active_wave_units:
		if not is_instance_valid(u) or u.current_state == Unit.State.DEAD:
			units_to_remove.append(u)
			continue

		# 1. Health threshold retreat
		var hp_ratio := u.current_hp / (u.data.hp if u.data else 100.0)
		if hp_ratio <= ai_data.retreat_health_threshold:
			_order_unit_retreat(u)
			units_to_remove.append(u)
			units_retreated += 1
			continue

		# 2. Local Outnumbered ratio check (300px local engagement radius)
		var local_friendly := _count_units_in_radius(u.global_position, 300.0, 1)
		var local_player := _count_units_in_radius(u.global_position, 300.0, 0)

		if local_player >= 2:
			var ratio := float(local_friendly) / float(local_player)
			if ratio < ai_data.outnumbered_ratio_threshold:
				# Squad is outmatched! Fall back to staging area
				_order_unit_retreat(u)
				units_to_remove.append(u)
				units_retreated += 1

	for u in units_to_remove:
		active_wave_units.erase(u)

	if units_retreated > 0:
		retreat_ordered.emit(units_retreated)

func _order_unit_retreat(u: Unit) -> void:
	# Random spread around staging/base perimeter to prevent clustering
	var offset := Vector2(randf_range(-60, 60), randf_range(-60, 60))
	var retreat_pos := ai_data.staging_area + offset
	u.order_move(retreat_pos)
	staging_units.append(u)

## 4-Tier Target Priority Implementation:
## Tier 1: Nearest Active Threat (Player units)
## Tier 2: Defensive Structures (Player Defense Turrets)
## Tier 3: Production Structures (Player Barracks / Factories)
## Tier 4: Player Headquarters (Allied HQ)
func _issue_attack_wave_orders() -> void:
	var player_turrets := _get_player_buildings_by_type(BuildingData.BuildingType.TURRET)
	var player_production := _get_player_buildings_by_type(BuildingData.BuildingType.BARRACKS)
	player_production.append_array(_get_player_buildings_by_type(BuildingData.BuildingType.FACTORY))
	var player_hq := _get_player_hq()

	for u in active_wave_units:
		if not is_instance_valid(u) or u.current_state == Unit.State.DEAD:
			continue

		# Tier 1: Nearest Threat within aggressive chase range
		var nearest_player_unit := _find_nearest_unit(u.global_position, 0, ai_data.aggressive_chase_range)
		if nearest_player_unit != null:
			u.order_attack_target(nearest_player_unit)
			continue

		# Tier 2: Player Defense Turret (Prioritize destroying choke-point turrets)
		if ai_data.prioritize_turrets and not player_turrets.is_empty():
			var closest_turret := _find_closest_building_from_list(u.global_position, player_turrets)
			if closest_turret != null:
				u.order_attack_building(closest_turret)
				continue

		# Tier 3: Player Production Buildings (Barracks / Factory)
		if not player_production.is_empty():
			var closest_prod := _find_closest_building_from_list(u.global_position, player_production)
			if closest_prod != null:
				u.order_attack_building(closest_prod)
				continue

		# Tier 4: Player Headquarters (Final Objective)
		if player_hq != null:
			u.order_attack_building(player_hq)
		else:
			u.order_attack_move(ai_data.player_hq_position)

## Base Defense Interception
func _trigger_base_defense(invaders: Array[Unit]) -> void:
	_change_state(AIState.DEFENDING)
	base_defense_triggered.emit(invaders.size())

	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.enemy_base_alarm_triggered.emit(invaders.size())

	_gather_idle_axis_units()
	# Mobilize staging units and recall closest wave units if available
	base_defenders = staging_units.duplicate()
	staging_units.clear()

	_issue_defense_orders(invaders)

func _issue_defense_orders(invaders: Array[Unit]) -> void:
	if invaders.is_empty():
		return

	var primary_target := invaders[0]
	for def in base_defenders:
		if is_instance_valid(def) and def.current_state != Unit.State.DEAD:
			def.order_attack_target(primary_target)

## Helper Methods & Queries
func _change_state(new_state: AIState) -> void:
	current_state = new_state
	var s_name := "GATHERING"
	match current_state:
		AIState.GATHERING: s_name = "GATHERING"
		AIState.ATTACKING: s_name = "ATTACKING"
		AIState.RETREATING: s_name = "RETREATING"
		AIState.DEFENDING: s_name = "DEFENDING"

	ai_state_changed.emit(current_state, s_name)
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.enemy_ai_state_changed.emit(s_name)

func _gather_idle_axis_units() -> void:
	var units := get_tree().get_nodes_in_group("units")
	for node in units:
		if node is Unit and node.data and node.data.team == 1 and node.current_state != Unit.State.DEAD:
			var u: Unit = node
			if not active_wave_units.has(u) and not staging_units.has(u) and not base_defenders.has(u):
				staging_units.append(u)
				u.order_move(ai_data.staging_area + Vector2(randf_range(-40, 40), randf_range(-40, 40)))

func _cleanup_dead_units() -> void:
	staging_units = staging_units.filter(func(u): return is_instance_valid(u) and u.current_state != Unit.State.DEAD)
	active_wave_units = active_wave_units.filter(func(u): return is_instance_valid(u) and u.current_state != Unit.State.DEAD)
	base_defenders = base_defenders.filter(func(u): return is_instance_valid(u) and u.current_state != Unit.State.DEAD)

func _get_player_units_in_base_perimeter() -> Array[Unit]:
	var invaders: Array[Unit] = []
	var units := get_tree().get_nodes_in_group("units")
	var rad_sq: float = ai_data.base_defense_radius * ai_data.base_defense_radius

	for node in units:
		if node is Unit and node.data and node.data.team == 0 and node.current_state != Unit.State.DEAD:
			if node.global_position.distance_squared_to(ai_data.base_position) <= rad_sq:
				invaders.append(node as Unit)

	return invaders

func _count_units_in_radius(center: Vector2, radius: float, faction: int) -> int:
	var count := 0
	var rad_sq := radius * radius
	var units := get_tree().get_nodes_in_group("units")
	for node in units:
		if node is Unit and node.data and node.data.team == faction and node.current_state != Unit.State.DEAD:
			if center.distance_squared_to(node.global_position) <= rad_sq:
				count += 1
	return count

func _find_nearest_unit(pos: Vector2, faction: int, max_range: float) -> Unit:
	var best_unit: Unit = null
	var min_dist_sq := max_range * max_range
	var units := get_tree().get_nodes_in_group("units")

	for node in units:
		if node is Unit and node.data and node.data.team == faction and node.current_state != Unit.State.DEAD:
			var d_sq := pos.distance_squared_to(node.global_position)
			if d_sq <= min_dist_sq:
				min_dist_sq = d_sq
				best_unit = node as Unit

	return best_unit

func _find_closest_idle_axis_unit(pos: Vector2) -> Unit:
	var best_unit: Unit = null
	var min_dist_sq := 400.0 * 400.0

	for u in staging_units:
		if is_instance_valid(u) and u.current_state == Unit.State.IDLE:
			var d_sq := pos.distance_squared_to(u.global_position)
			if d_sq <= min_dist_sq:
				min_dist_sq = d_sq
				best_unit = u

	return best_unit

func _get_player_buildings_by_type(b_type: BuildingData.BuildingType) -> Array[Building]:
	var list: Array[Building] = []
	var buildings := get_tree().get_nodes_in_group("buildings")
	for node in buildings:
		if node is Building and node.data and node.data.faction == 0 and node.current_hp > 0.0:
			if node.data.building_type == b_type:
				list.append(node as Building)
	return list

func _get_player_hq() -> Building:
	var buildings := get_tree().get_nodes_in_group("buildings")
	for node in buildings:
		if node is Building and node.data and node.data.faction == 0 and node.current_hp > 0.0:
			if node.data.building_type == BuildingData.BuildingType.HQ:
				return node as Building
	return null

func _find_closest_building_from_list(pos: Vector2, list: Array[Building]) -> Building:
	var best: Building = null
	var min_dist_sq := INF
	for b in list:
		if is_instance_valid(b) and b.current_hp > 0.0:
			var d_sq := pos.distance_squared_to(b.global_position)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				best = b
	return best

func _on_building_damaged(b: Node2D, _hp: float, _max: float) -> void:
	if b is Building and b.data and b.data.faction == 1:
		# Axis building under fire! Sound base defense alarm
		base_alert_timer = BASE_ALERT_DURATION
		if current_state != AIState.DEFENDING:
			var invaders := _get_player_units_in_base_perimeter()
			_trigger_base_defense(invaders)

func _on_unit_killed(killed_unit: CharacterBody2D, _killer: CharacterBody2D) -> void:
	if killed_unit is Unit and killed_unit.data and killed_unit.data.team == 1:
		active_wave_units.erase(killed_unit)
		staging_units.erase(killed_unit)
		base_defenders.erase(killed_unit)
