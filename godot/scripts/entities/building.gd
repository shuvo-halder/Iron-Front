class_name Building
extends StaticBody2D

## Building structure in Iron Front (HQ, Barracks, Factory, Turret).
## Features:
## - Construction state with progress bar
## - Unit production queue (up to 5 queued units)
## - Moveable Rally Point with visual line & flag
## - Passive supply generation
## - Automated defense turret with anti-air missile defense

@export var data: BuildingData

var current_hp: float = 1000.0
var is_under_construction: bool = false
var construction_timer: float = 0.0
var is_selected: bool = false
var rally_point: Vector2 = Vector2.ZERO
var target_enemy: Unit = null
var turret_attack_timer: float = 0.0
var turret_angle: float = 0.0

# Queue items: Array of { "res_path": String, "time_left": float, "total_time": float, "display_name": String }
var production_queue: Array[Dictionary] = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

func _ready() -> void:
	add_to_group("buildings")
	if data:
		initialize_building(data, is_under_construction)
	queue_redraw()

func initialize_building(p_data: BuildingData, under_construction: bool = false) -> void:
	data = p_data
	current_hp = data.max_health
	is_under_construction = under_construction
	construction_timer = data.build_time if under_construction else 0.0
	rally_point = global_position + Vector2(0, data.footprint_radius + 45.0)

	if not under_construction:
		_on_construction_finished()

func _on_construction_finished() -> void:
	is_under_construction = false
	if data and data.passive_supply_rate > 0.0:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("register_building_income"):
			gm.register_building_income(data.passive_supply_rate)
	
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.building_constructed.emit(self)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if is_under_construction:
		construction_timer -= delta
		if construction_timer <= 0.0:
			_on_construction_finished()
		queue_redraw()
		return

	# Process unit production
	_process_production_queue(delta)

	# Process defense turret automated fire
	if data and data.is_defense_turret:
		_process_turret_combat(delta)

func _process_production_queue(delta: float) -> void:
	if production_queue.is_empty():
		return

	var current_item = production_queue[0]
	current_item.time_left -= delta
	var progress: float = 1.0 - clampf(current_item.time_left / current_item.total_time, 0.0, 1.0)

	var bus = get_node_or_null("/root/EventBus")
	if bus and is_selected:
		bus.production_queue_updated.emit(self, production_queue, progress)

	if current_item.time_left <= 0.0:
		# Unit production complete! Spawn unit
		var res_path: String = current_item.res_path
		production_queue.remove_at(0)
		_spawn_completed_unit(res_path)

	queue_redraw()

func enqueue_unit(unit_res_path: String) -> bool:
	if is_under_construction or production_queue.size() >= 5:
		return false

	var u_data = load(unit_res_path) as UnitData
	if not u_data:
		return false

	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.can_afford(u_data.cost):
		return false

	gm.spend_supply(u_data.cost)

	# Calculate build time based on unit cost (scaled for mobile RTS: ~3.0s to 7.0s)
	var build_sec := clampf(u_data.cost * 0.025, 2.5, 7.5)
	production_queue.append({
		"res_path": unit_res_path,
		"time_left": build_sec,
		"total_time": build_sec,
		"display_name": u_data.display_name
	})

	var bus = get_node_or_null("/root/EventBus")
	if bus and is_selected:
		bus.production_queue_updated.emit(self, production_queue, 0.0)

	queue_redraw()
	return true

func _spawn_completed_unit(res_path: String) -> void:
	var exit_pos := global_position + Vector2(0, data.footprint_radius + 15.0)
	var main_game = get_tree().root.find_child("MainGame", true, false)
	if not main_game or not main_game.has_method("_spawn_unit_at"):
		return

	var spawned: Unit = main_game.call("_spawn_unit_at", res_path, exit_pos, data.faction)
	if is_instance_valid(spawned):
		if rally_point != Vector2.ZERO:
			spawned.order_move(rally_point)
		
		var bus = get_node_or_null("/root/EventBus")
		if bus:
			bus.unit_spawned.emit(spawned)

func _process_turret_combat(delta: float) -> void:
	if turret_attack_timer > 0.0:
		turret_attack_timer -= delta

	# Scan for nearest enemy target (both ground and air!)
	if not is_instance_valid(target_enemy) or target_enemy.current_state == Unit.State.DEAD or global_position.distance_to(target_enemy.global_position) > data.turret_range:
		target_enemy = _find_nearest_enemy_target()

	if is_instance_valid(target_enemy):
		var dir := (target_enemy.global_position - global_position).normalized()
		turret_angle = rotate_toward(turret_angle, dir.angle(), 4.0 * delta)

		if turret_attack_timer <= 0.0:
			turret_attack_timer = data.turret_cooldown
			_fire_turret_missile(target_enemy)
		queue_redraw()

func _find_nearest_enemy_target() -> Unit:
	var best_u: Unit = null
	var min_dist_sq := data.turret_range * data.turret_range
	var units := get_tree().get_nodes_in_group("units")
	for node in units:
		if node is Unit and node.current_state != Unit.State.DEAD and node.faction != data.faction:
			var d_sq := global_position.distance_squared_to(node.global_position)
			if d_sq <= min_dist_sq:
				min_dist_sq = d_sq
				best_u = node
	return best_u

func _fire_turret_missile(target: Unit) -> void:
	var pool = get_node_or_null("/root/ObjectPool")
	var barrel_tip := global_position + Vector2.RIGHT.rotated(turret_angle) * (data.footprint_radius * 0.7)
	if pool:
		pool.spawn_muzzle_flash(barrel_tip, (target.global_position - barrel_tip).normalized(), 1.0)
		pool.spawn_projectile(
			barrel_tip,
			target.global_position,
			500.0,
			data.turret_damage,
			45.0,
			data.faction,
			1, # ROCKET
			1, # EXPLOSIVE (can hit air!)
			40.0,
			self
		)

func set_rally_point(pos: Vector2) -> void:
	rally_point = pos
	queue_redraw()

func set_selected(selected: bool) -> void:
	is_selected = selected
	var bus = get_node_or_null("/root/EventBus")
	if bus and is_selected:
		bus.building_selected.emit(self)
		var progress: float = 0.0
		if not production_queue.is_empty():
			progress = 1.0 - (production_queue[0].time_left / production_queue[0].total_time)
		bus.production_queue_updated.emit(self, production_queue, progress)
	queue_redraw()

func take_damage(amount: float, armor_pen: float, hit_dir: Vector2, _attacker: Node2D = null, _dmg_type: int = 0) -> void:
	var effective_armor := 30.0
	var diff := effective_armor - armor_pen
	var mult := clampf(1.0 - (diff / 50.0), 0.2, 1.5)
	current_hp -= maxf(amount * mult, 1.0)

	if current_hp <= 0.0:
		die()
	queue_redraw()

func die() -> void:
	if data and data.passive_supply_rate > 0.0:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("unregister_building_income"):
			gm.unregister_building_income(data.passive_supply_rate)

	var pool = get_node_or_null("/root/ObjectPool")
	if pool:
		pool.spawn_explosion(global_position, 1.8, true)

	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.building_destroyed.emit(self)

	queue_free()

func _draw() -> void:
	if not data:
		return

	var r := data.footprint_radius
	var color := data.building_color
	if is_under_construction:
		color = Color(0.6, 0.6, 0.6, 0.6)

	# 1. Base footprint
	draw_circle(Vector2.ZERO, r, color)
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(0.1, 0.1, 0.1), 3.0)

	# 2. Distinctive Architecture
	match data.building_type:
		BuildingData.BuildingType.HQ:
			# Fortified Command Bunker + Comms Dish
			draw_rect(Rect2(-r * 0.65, -r * 0.65, r * 1.3, r * 1.3), Color(0.18, 0.22, 0.22))
			draw_circle(Vector2.ZERO, r * 0.4, Color(0.35, 0.45, 0.45))
			draw_arc(Vector2(0, -r * 0.1), r * 0.25, -PI * 0.8, -PI * 0.2, 12, Color.WHITE, 2.5) # Dish
			draw_line(Vector2(0, -r * 0.1), Vector2(r * 0.25, -r * 0.35), Color.WHITE, 2.0)

		BuildingData.BuildingType.BARRACKS:
			# Quonset hut with roof ribs and twin entrance doors
			draw_rect(Rect2(-r * 0.7, -r * 0.5, r * 1.4, r * 1.0), Color(0.2, 0.25, 0.2))
			draw_line(Vector2(-r * 0.7, 0), Vector2(r * 0.7, 0), Color(0.1, 0.15, 0.1), 2.5)
			draw_rect(Rect2(-r * 0.4, r * 0.2, r * 0.25, r * 0.3), Color(0.9, 0.7, 0.2)) # Door
			draw_rect(Rect2(r * 0.15, r * 0.2, r * 0.25, r * 0.3), Color(0.9, 0.7, 0.2)) # Door

		BuildingData.BuildingType.FACTORY:
			# Heavy industrial plant with dual smokestacks and loading bay
			draw_rect(Rect2(-r * 0.75, -r * 0.6, r * 1.5, r * 1.2), Color(0.25, 0.25, 0.28))
			draw_circle(Vector2(-r * 0.4, -r * 0.3), r * 0.18, Color(0.12, 0.12, 0.12)) # Stack
			draw_circle(Vector2(-r * 0.4, r * 0.3), r * 0.18, Color(0.12, 0.12, 0.12)) # Stack
			draw_rect(Rect2(r * 0.2, -r * 0.35, r * 0.55, r * 0.7), Color(0.85, 0.75, 0.2)) # Bay

		BuildingData.BuildingType.TURRET:
			# Reinforced concrete pillbox with revolving twin missile pods
			draw_circle(Vector2.ZERO, r * 0.7, Color(0.2, 0.22, 0.25))
			var pod_len := r * 0.85
			var t_dir := Vector2.RIGHT.rotated(turret_angle)
			var t_side := t_dir.orthogonal()
			draw_line(Vector2.ZERO, t_dir * pod_len, Color(0.1, 0.1, 0.1), 5.0)
			draw_rect(Rect2(-t_side * 6.0, Vector2(12, 12)), Color(0.8, 0.2, 0.2))

	# 3. Selection Ring & Rally Point Line
	if is_selected:
		var sel_color := Color(0.3, 0.95, 0.5, 0.9)
		draw_arc(Vector2.ZERO, r + 8.0, 0, TAU, 36, sel_color, 2.0)

		# Rally line & flag
		if rally_point != Vector2.ZERO and not is_under_construction:
			var rel_rally := to_local(rally_point)
			draw_line(Vector2.ZERO, rel_rally, Color(0.3, 0.95, 0.5, 0.6), 2.0)
			# Flag icon at rally point
			draw_line(rel_rally, rel_rally + Vector2(0, -18), Color.WHITE, 2.0)
			var flag_poly := PackedVector2Array([
				rel_rally + Vector2(0, -18),
				rel_rally + Vector2(14, -12),
				rel_rally + Vector2(0, -6)
			])
			draw_colored_polygon(flag_poly, Color(0.3, 0.95, 0.5))

	# 4. Progress / Health Bar
	var bar_w := r * 2.0
	var bar_h := 5.0
	var bar_y := -r - 12.0

	if is_under_construction:
		# Construction progress bar (Orange/Yellow)
		var progress := 1.0 - (construction_timer / data.build_time)
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.8))
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * progress, bar_h), Color(1.0, 0.75, 0.2))
	else:
		# Health bar
		var hp_ratio := clampf(current_hp / data.max_health, 0.0, 1.0)
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h), Color(0.1, 0.1, 0.1, 0.8))
		var hp_color := Color(0.2, 0.85, 0.3) if hp_ratio > 0.5 else Color(0.9, 0.25, 0.25)
		draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * hp_ratio, bar_h), hp_color)

		# Production queue progress overlay
		if not production_queue.is_empty():
			var cur := production_queue[0]
			var prod_ratio := 1.0 - (cur.time_left / cur.total_time)
			draw_rect(Rect2(-bar_w * 0.5, bar_y - 6.0, bar_w, 3.0), Color(0.1, 0.1, 0.1, 0.7))
			draw_rect(Rect2(-bar_w * 0.5, bar_y - 6.0, bar_w * prod_ratio, 3.0), Color(0.2, 0.8, 1.0))
