class_name Unit
extends CharacterBody2D

## Base Unit entity driven by UnitData Resource.
## Features:
## - Auto-targeting nearest enemy in range when IDLE / ATTACK_MOVE
## - Damage types vs armor multipliers (Infantry / Vehicle / Air)
## - Directional armor calculation (Front / Side / Rear)
## - Helicopter anti-air rules (Helicopter can only be hit by rocket soldier & turret)
## - Muzzle flash, hit sparks, and death effects via ObjectPool
## - EventBus signals: unit_killed, unit_damaged

enum State { IDLE, MOVE, ATTACK, DEAD }

@export var data: UnitData

var current_state: State = State.IDLE
var current_hp: float = 100.0
var is_selected: bool = false
var is_attack_moving: bool = false
var target_unit: Unit = null
var attack_timer: float = 0.0
var scan_timer: float = 0.0
var faction: int:
	get: return data.team if data else 0
	set(v):
		if data:
			data.team = v

# Rotor animation for airborne units
var _rotor_angle: float = 0.0

# Node references
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D if has_node("NavigationAgent2D") else null
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var selection_ring: Node2D = $SelectionRing if has_node("SelectionRing") else null

# Team Colors: 0 = Allied (Green), 1 = Axis (Red)
const TEAM_COLORS = {
	0: Color(0.25, 0.75, 0.35), # Allied Green
	1: Color(0.85, 0.25, 0.25)  # Axis Red
}

var is_dead: bool:
	get: return current_state == State.DEAD

func _ready() -> void:
	add_to_group("units")
	scan_timer = randf_range(0.05, 0.25)
	if data:
		initialize_unit(data)
	if nav_agent:
		nav_agent.velocity_computed.connect(_on_velocity_computed)
	update_visuals()

func initialize_unit(p_data: UnitData) -> void:
	data = p_data
	current_hp = data.hp
	attack_timer = randf_range(0.0, data.attack_cooldown)
	if health_bar:
		health_bar.max_value = data.hp
		health_bar.value = current_hp
	if nav_agent:
		nav_agent.max_speed = data.speed
		nav_agent.radius = data.unit_radius
		nav_agent.neighbor_distance = 160.0
		nav_agent.max_neighbors = 12
		nav_agent.time_horizon_agents = 0.8
		nav_agent.avoidance_enabled = true
	queue_redraw()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	# Animate helicopter rotors
	if data and data.armor_type == UnitData.ArmorType.AIR:
		_rotor_angle = fmod(_rotor_angle + delta * 28.0, TAU)
		queue_redraw()

	# Auto-target nearest enemy when IDLE or ATTACK_MOVE
	if current_state == State.IDLE or (current_state == State.MOVE and is_attack_moving):
		scan_timer -= delta
		if scan_timer <= 0.0:
			scan_timer = 0.2 + randf() * 0.08
			_scan_and_auto_target()

	match current_state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			move_and_slide()

		State.MOVE:
			_process_movement(delta)

		State.ATTACK:
			_process_attack(delta)

func _scan_and_auto_target() -> void:
	var my_range := data.range if data else 220.0
	var my_team := faction
	var best_target: Unit = null
	var min_dist_sq := my_range * my_range

	var candidates := get_tree().get_nodes_in_group("units")
	for node in candidates:
		if node is Unit and node != self and node.current_state != State.DEAD:
			var cand: Unit = node
			if cand.faction == my_team:
				continue
			# Check targeting rules (e.g. Helicopter anti-air restriction)
			if not can_target(cand):
				continue

			var d_sq := global_position.distance_squared_to(cand.global_position)
			if d_sq <= min_dist_sq:
				min_dist_sq = d_sq
				best_target = cand

	if best_target != null:
		set_attack_target(best_target)

## Determines if this unit is allowed to engage the target.
## Rule: Helicopter can ONLY be hit by rocket soldiers and turrets.
func can_target(target: Unit) -> bool:
	if target == null or target.current_state == State.DEAD or target.faction == faction:
		return false
	if target.data and target.data.armor_type == UnitData.ArmorType.AIR:
		if data == null or not data.can_target_air:
			return false
	return true

func _process_movement(delta: float) -> void:
	if not nav_agent or nav_agent.is_navigation_finished():
		current_state = State.IDLE
		is_attack_moving = false
		velocity = Vector2.ZERO
		return

	var next_pos := nav_agent.get_next_path_position()
	var dir := (next_pos - global_position).normalized()
	var spd := data.speed if data else 100.0
	var desired_velocity := dir * spd

	rotation = rotate_toward(rotation, dir.angle(), (data.rotation_speed if data else 4.0) * delta)

	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired_velocity)
	else:
		_on_velocity_computed(desired_velocity)

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()

func _process_attack(delta: float) -> void:
	if not is_instance_valid(target_unit) or target_unit.current_state == State.DEAD or not can_target(target_unit):
		target_unit = null
		current_state = State.IDLE
		return

	var dist := global_position.distance_to(target_unit.global_position)
	var max_range := data.range if data else 200.0

	if dist > max_range * 1.15:
		# Reposition within firing range
		set_move_target(target_unit.global_position)
		current_state = State.MOVE
		return

	# Face target
	var dir := (target_unit.global_position - global_position).normalized()
	rotation = rotate_toward(rotation, dir.angle(), (data.turret_rotation_speed if data else 4.5) * delta)

	# Fire weapon when reload cooldown expires
	if attack_timer <= 0.0:
		attack_timer = data.attack_cooldown if data else 1.0
		_execute_attack(target_unit)

func _execute_attack(target: Unit) -> void:
	var pool = get_node_or_null("/root/ObjectPool")
	var rad := data.unit_radius if data else 18.0
	var barrel_tip := global_position + Vector2.RIGHT.rotated(rotation) * (rad + 6.0)
	var dir := (target.global_position - barrel_tip).normalized()

	# 1. Spawn Muzzle Flash
	if pool:
		var flash_scale := 1.2 if (data and data.projectile_type == UnitData.ProjectileType.TANK_SHELL) else 0.8
		pool.spawn_muzzle_flash(barrel_tip, dir, flash_scale)

	# 2. Fire Pooled Projectile with full typing
	var p_type := data.projectile_type if data else 0
	var d_type := data.damage_type if data else 0
	var spd := data.projectile_speed if data else 550.0
	var dmg := data.damage if data else 20.0
	var pen := data.armor_penetration if data else 15.0
	var splash := data.splash_radius if data else 0.0

	if pool:
		pool.spawn_projectile(barrel_tip, target.global_position, spd, dmg, pen, faction, p_type, d_type, splash, self)
	else:
		target.take_damage(dmg, pen, dir, self, d_type)

func take_damage(incoming_damage: float, armor_pen: float, hit_dir: Vector2, attacker: Node2D = null, dmg_type: int = 0) -> void:
	if current_state == State.DEAD:
		return

	var target_armor_type: int = data.armor_type if data else UnitData.ArmorType.INFANTRY

	# 1. Damage Type vs Armor Multiplier
	var type_multiplier := UnitData.get_damage_multiplier(dmg_type as UnitData.DamageType, target_armor_type as UnitData.ArmorType)
	if type_multiplier <= 0.0:
		# Immune! (e.g. Helicopter hit by small arms or non-explosive)
		return

	# 2. Directional Armor calculation (Front, Side, Rear)
	var effective_armor := data.armor_front if data else 10.0
	var is_rear_hit := false

	if target_armor_type == UnitData.ArmorType.VEHICLE and data != null:
		var local_hit_dir := (-hit_dir).rotated(-rotation)
		var dot_forward := local_hit_dir.dot(Vector2.RIGHT)
		if dot_forward > 0.4:
			effective_armor = data.armor_front
		elif dot_forward < -0.4:
			effective_armor = data.armor_rear
			is_rear_hit = true
		else:
			effective_armor = data.armor_side

	# 3. Armor Penetration Formula
	var diff := effective_armor - armor_pen
	var armor_mult := clampf(1.0 - (diff / (effective_armor + 22.0)), 0.15, 1.8)
	var actual_damage := maxf(incoming_damage * type_multiplier * armor_mult, 1.0)

	current_hp -= actual_damage
	update_visuals()

	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.unit_damaged.emit(self, actual_damage, is_rear_hit)

	# Auto-retaliate if idle and attacker is valid
	if current_state == State.IDLE and attacker is Unit and can_target(attacker):
		set_attack_target(attacker)

	if current_hp <= 0.0:
		die(attacker)

func die(killer: Node2D = null) -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	if health_bar:
		health_bar.visible = false
	if selection_ring:
		selection_ring.visible = false

	# Spawn death effects
	var pool = get_node_or_null("/root/ObjectPool")
	if pool:
		var is_veh := data != null and (data.armor_type == UnitData.ArmorType.VEHICLE or data.armor_type == UnitData.ArmorType.AIR)
		pool.spawn_death_effect(global_position, is_veh, 1.1 if is_veh else 0.8)

	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.unit_killed.emit(self, killer as CharacterBody2D)

	queue_redraw()
	get_tree().create_timer(1.2).timeout.connect(queue_free)

func set_move_target(dest: Vector2) -> void:
	target_unit = null
	current_state = State.MOVE
	if nav_agent:
		nav_agent.target_position = dest

func set_attack_target(enemy: Unit) -> void:
	target_unit = enemy
	current_state = State.ATTACK

func order_move(dest: Vector2) -> void:
	is_attack_moving = false
	set_move_target(dest)

func order_attack_move(dest: Vector2) -> void:
	is_attack_moving = true
	set_move_target(dest)

func order_attack_target(enemy: Unit) -> void:
	if can_target(enemy):
		set_attack_target(enemy)

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_ring:
		selection_ring.visible = is_selected
	if health_bar:
		health_bar.visible = is_selected or current_hp < (data.hp if data else 100.0)
	queue_redraw()

func update_visuals() -> void:
	if health_bar and data:
		health_bar.max_value = data.hp
		health_bar.value = current_hp
		health_bar.visible = is_selected or current_hp < data.hp

func _draw() -> void:
	var team_idx := faction
	var color: Color = TEAM_COLORS.get(team_idx, Color.WHITE)
	if current_state == State.DEAD:
		color = Color(0.18, 0.18, 0.18)

	var r := data.unit_radius if data else 18.0

	# Tactical Selection Ring & Brackets
	if is_selected and current_state != State.DEAD:
		var ring_color := Color(0.3, 0.95, 0.5, 0.9)
		draw_arc(Vector2.ZERO, r + 5.0, 0, TAU, 28, ring_color, 1.5)
		var b_len := 5.0
		var b_off := r + 6.0
		draw_line(Vector2(-b_off, -b_off), Vector2(-b_off + b_len, -b_off), ring_color, 2.0)
		draw_line(Vector2(-b_off, -b_off), Vector2(-b_off, -b_off + b_len), ring_color, 2.0)
		draw_line(Vector2(b_off, -b_off), Vector2(b_off - b_len, -b_off), ring_color, 2.0)
		draw_line(Vector2(b_off, -b_off), Vector2(b_off, -b_off + b_len), ring_color, 2.0)
		draw_line(Vector2(-b_off, b_off), Vector2(-b_off + b_len, b_off), ring_color, 2.0)
		draw_line(Vector2(-b_off, b_off), Vector2(-b_off, b_off - b_len), ring_color, 2.0)
		draw_line(Vector2(b_off, b_off), Vector2(b_off - b_len, b_off), ring_color, 2.0)
		draw_line(Vector2(b_off, b_off), Vector2(b_off, b_off - b_len), ring_color, 2.0)

	var u_type := data.unit_type if data else UnitData.UnitType.RIFLE_SQUAD
	match u_type:
		UnitData.UnitType.COMBAT_ENGINEER:
			var pts := PackedVector2Array([Vector2(r, 0), Vector2(0, -r * 0.7), Vector2(-r, 0), Vector2(0, r * 0.7)])
			draw_colored_polygon(pts, color)
			draw_circle(Vector2.ZERO, r * 0.35, Color(0.9, 0.9, 0.2))

		UnitData.UnitType.RIFLE_SQUAD:
			draw_circle(Vector2(r * 0.4, 0), r * 0.4, color)
			draw_circle(Vector2(-r * 0.35, -r * 0.35), r * 0.35, color)
			draw_circle(Vector2(-r * 0.35, r * 0.35), r * 0.35, color)

		UnitData.UnitType.ANTI_TANK_TEAM:
			# Heavy soldier with long shoulder-mounted rocket launcher tube
			var pts := PackedVector2Array([Vector2(r, 0), Vector2(-r * 0.8, -r * 0.7), Vector2(-r * 0.8, r * 0.7)])
			draw_colored_polygon(pts, color)
			draw_line(Vector2(-r * 0.4, 0), Vector2(r * 1.5, 0), Color(0.1, 0.1, 0.1), 3.5) # Rocket tube
			draw_circle(Vector2(r * 1.5, 0), 2.5, Color(0.9, 0.2, 0.2)) # Rocket tip

		UnitData.UnitType.SCOUT_CAR:
			draw_rect(Rect2(-r, -r * 0.6, r * 2.0, r * 1.2), color)
			draw_rect(Rect2(-r * 0.8, -r * 0.8, r * 0.4, r * 0.25), Color.BLACK)
			draw_rect(Rect2(r * 0.4, -r * 0.8, r * 0.4, r * 0.25), Color.BLACK)
			draw_rect(Rect2(-r * 0.8, r * 0.55, r * 0.4, r * 0.25), Color.BLACK)
			draw_rect(Rect2(r * 0.4, r * 0.55, r * 0.4, r * 0.25), Color.BLACK)
			draw_line(Vector2.ZERO, Vector2(r * 1.3, 0), Color(0.2, 0.2, 0.2), 2.5)

		UnitData.UnitType.MEDIUM_TANK:
			draw_rect(Rect2(-r * 1.1, -r * 0.85, r * 2.2, r * 0.35), Color(0.15, 0.15, 0.15))
			draw_rect(Rect2(-r * 1.1, r * 0.5, r * 2.2, r * 0.35), Color(0.15, 0.15, 0.15))
			draw_rect(Rect2(-r * 0.9, -r * 0.6, r * 1.8, r * 1.2), color)
			draw_circle(Vector2.ZERO, r * 0.55, Color(0.2, 0.2, 0.2))
			draw_line(Vector2.ZERO, Vector2(r * 1.6, 0), Color(0.2, 0.2, 0.2), 4.0)

		UnitData.UnitType.HEAVY_TANK:
			draw_rect(Rect2(-r * 1.2, -r * 0.95, r * 2.4, r * 0.4), Color(0.1, 0.1, 0.1))
			draw_rect(Rect2(-r * 1.2, r * 0.55, r * 2.4, r * 0.4), Color(0.1, 0.1, 0.1))
			draw_rect(Rect2(-r, -r * 0.7, r * 2.0, r * 1.4), color)
			draw_circle(Vector2.ZERO, r * 0.65, Color(0.15, 0.15, 0.15))
			draw_line(Vector2.ZERO, Vector2(r * 2.1, 0), Color(0.15, 0.15, 0.15), 5.5)

		UnitData.UnitType.ATTACK_HELICOPTER:
			# Shadow underneath
			draw_circle(Vector2(6, 12), r * 0.7, Color(0.0, 0.0, 0.0, 0.25))
			# Fuselage
			draw_colored_polygon(PackedVector2Array([
				Vector2(r * 1.2, 0),
				Vector2(r * 0.4, -r * 0.5),
				Vector2(-r * 0.6, -r * 0.35),
				Vector2(-r * 1.4, 0),
				Vector2(-r * 0.6, r * 0.35),
				Vector2(r * 0.4, r * 0.5)
			]), color)
			# Cockpit canopy
			draw_circle(Vector2(r * 0.6, 0), r * 0.3, Color(0.2, 0.8, 1.0, 0.75))
			# Dual rocket pods
			draw_rect(Rect2(0, -r * 0.75, r * 0.5, r * 0.25), Color(0.2, 0.2, 0.2))
			draw_rect(Rect2(0, r * 0.5, r * 0.5, r * 0.25), Color(0.2, 0.2, 0.2))
			# Spinning main rotor blades
			var rotor_r := r * 1.6
			var blade1 := Vector2.RIGHT.rotated(_rotor_angle) * rotor_r
			var blade2 := Vector2.RIGHT.rotated(_rotor_angle + PI * 0.5) * rotor_r
			draw_line(-blade1, blade1, Color(0.9, 0.9, 0.9, 0.75), 2.5)
			draw_line(-blade2, blade2, Color(0.9, 0.9, 0.9, 0.75), 2.5)
			draw_circle(Vector2.ZERO, 3.5, Color.BLACK)
