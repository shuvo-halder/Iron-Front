class_name Projectile
extends Area2D

## Pooled ballistic projectile supporting Bullets, Rockets (with AoE splash), and Tank Shells.
## Implements damage types vs armor multipliers, helicopter anti-air rules, and zero-allocation recycling.

var projectile_type: int = 0  # UnitData.ProjectileType.BULLET
var damage_type: int = 0      # UnitData.DamageType.KINETIC
var speed: float = 550.0
var damage: float = 25.0
var armor_penetration: float = 20.0
var shooter_faction: int = 0
var splash_radius: float = 0.0
var shooter_node: Node2D = null

var direction: Vector2 = Vector2.RIGHT
var distance_traveled: float = 0.0
var max_range: float = 600.0

# Smoke particle trail for rockets
var smoke_trail: PackedVector2Array = []
var smoke_timers: PackedFloat32Array = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func initialize_projectile_typed(
	start_pos: Vector2,
	target_pos: Vector2,
	p_speed: float,
	p_damage: float,
	p_armor_pen: float,
	p_faction: int,
	p_proj_type: int,
	p_dmg_type: int,
	p_splash: float = 0.0,
	p_shooter: Node2D = null
) -> void:
	global_position = start_pos
	speed = p_speed
	damage = p_damage
	armor_penetration = p_armor_pen
	shooter_faction = p_faction
	projectile_type = p_proj_type
	damage_type = p_dmg_type
	splash_radius = p_splash
	shooter_node = p_shooter

	var dir_vec: Vector2 = target_pos - start_pos
	max_range = dir_vec.length() + 25.0
	direction = dir_vec.normalized()
	rotation = direction.angle()
	distance_traveled = 0.0
	smoke_trail.clear()
	smoke_timers.clear()
	queue_redraw()

func initialize_projectile(start_pos: Vector2, target_pos: Vector2, p_speed: float, p_damage: float, p_armor_pen: float, p_faction: int, p_splash: float = 0.0) -> void:
	initialize_projectile_typed(start_pos, target_pos, p_speed, p_damage, p_armor_pen, p_faction, 0, 0, p_splash, null)

func _physics_process(delta: float) -> void:
	var move_amt: float = speed * delta
	global_position += direction * move_amt
	distance_traveled += move_amt

	# Update rocket smoke trail
	if projectile_type == 1: # ROCKET
		if smoke_trail.size() < 12 and randf() < 0.6:
			smoke_trail.append(global_position - direction * 8.0)
			smoke_timers.append(0.25)
		for i in range(smoke_timers.size() - 1, -1, -1):
			smoke_timers[i] -= delta
			if smoke_timers[i] <= 0.0:
				smoke_trail.remove_at(i)
				smoke_timers.remove_at(i)

	queue_redraw()

	if distance_traveled >= max_range:
		_impact(global_position, null)

func _on_body_entered(body: Node2D) -> void:
	if not visible:
		return
	if body is Unit and body.faction != shooter_faction and body.current_state != Unit.State.DEAD:
		_impact(global_position, body)
	elif body is Building and body.data and body.data.faction != shooter_faction:
		_impact_building(global_position, body)

func _impact_building(pos: Vector2, b: Building) -> void:
	var pool = get_node_or_null("/root/ObjectPool")
	if is_instance_valid(b) and b.current_hp > 0.0:
		b.take_damage(damage, armor_penetration, direction, shooter_node, damage_type)
		if pool:
			pool.spawn_hit_effect(pos, -direction, true)

	if splash_radius > 0.0:
		_apply_splash_damage(pos, null)

	if pool:
		if splash_radius > 30.0 or projectile_type == 1:
			pool.spawn_explosion(pos, 0.9 if projectile_type == 1 else 0.7, projectile_type == 2)
		else:
			pool.spawn_explosion(pos, 0.4, false)
		pool.recycle_projectile(self)
	else:
		queue_free()

func _impact(pos: Vector2, direct_target: Unit) -> void:
	var pool = get_node_or_null("/root/ObjectPool")

	# 1. Direct hit resolution
	if direct_target != null:
		var can_damage := true
		# Helicopter immunity rule: Helicopter can only be hit by rocket soldier (EXPLOSIVE) and turret
		if direct_target.data and direct_target.data.armor_type == UnitData.ArmorType.AIR:
			if damage_type != UnitData.DamageType.EXPLOSIVE:
				can_damage = false

		if can_damage:
			direct_target.take_damage(damage, armor_penetration, direction, shooter_node, damage_type)
			if pool:
				var is_armor := direct_target.data != null and direct_target.data.armor_type == UnitData.ArmorType.VEHICLE
				pool.spawn_hit_effect(pos, -direction, is_armor)

	# 2. Area of Effect Splash Damage (Rockets and Tank Shells)
	if splash_radius > 0.0:
		_apply_splash_damage(pos, direct_target)

	# 3. Impact visual FX & recycle
	if pool:
		if splash_radius > 30.0 or projectile_type == 1: # Rocket / Heavy shell explosion
			pool.spawn_explosion(pos, 0.9 if projectile_type == 1 else 0.7, projectile_type == 2)
		else:
			pool.spawn_explosion(pos, 0.4, false)
		pool.recycle_projectile(self)
	else:
		queue_free()

func _apply_splash_damage(epicenter: Vector2, direct_hit_unit: Unit) -> void:
	# Query nearby units from scene tree or spatial grid
	var tree := get_tree()
	if not tree:
		return

	var units := tree.get_nodes_in_group("units")
	for node in units:
		if node is Unit and node != direct_hit_unit and node.current_state != Unit.State.DEAD:
			var target_unit: Unit = node
			if target_unit.faction == shooter_faction:
				continue # No friendly fire

			# Helicopter immunity check
			if target_unit.data and target_unit.data.armor_type == UnitData.ArmorType.AIR:
				if damage_type != UnitData.DamageType.EXPLOSIVE:
					continue

			var dist := epicenter.distance_to(target_unit.global_position)
			if dist <= splash_radius:
				var falloff := clampf(1.0 - (dist / splash_radius), 0.25, 1.0)
				var splash_dmg := damage * 0.75 * falloff
				var hit_dir := (target_unit.global_position - epicenter).normalized()
				if hit_dir == Vector2.ZERO:
					hit_dir = direction
				target_unit.take_damage(splash_dmg, armor_penetration * 0.6, hit_dir, shooter_node, damage_type)

func _draw() -> void:
	match projectile_type:
		0: # BULLET: Fast bright yellow tracer
			var tracer_len := 12.0
			draw_line(Vector2(-tracer_len, 0), Vector2(0, 0), Color(1.0, 0.9, 0.3), 2.0)
			draw_circle(Vector2(0, 0), 2.0, Color.WHITE)

		1: # ROCKET: Thick warhead with flame tail & smoke trail
			# Rocket body
			draw_rect(Rect2(-8.0, -3.0, 16.0, 6.0), Color(0.3, 0.35, 0.3))
			# Nosecone
			var cone := PackedVector2Array([Vector2(8.0, -3.0), Vector2(14.0, 0.0), Vector2(8.0, 3.0)])
			draw_colored_polygon(cone, Color(0.85, 0.2, 0.2))
			# Tail fins
			draw_line(Vector2(-8.0, -5.0), Vector2(-4.0, 0.0), Color(0.2, 0.2, 0.2), 2.0)
			draw_line(Vector2(-8.0, 5.0), Vector2(-4.0, 0.0), Color(0.2, 0.2, 0.2), 2.0)
			# Exhaust flame
			var flame_pts := PackedVector2Array([Vector2(-8.0, -2.5), Vector2(-16.0 - randf() * 6.0, 0.0), Vector2(-8.0, 2.5)])
			draw_colored_polygon(flame_pts, Color(1.0, 0.6, 0.1))

		2: # TANK_SHELL: Heavy armor-piercing projectile with incandescent glow
			draw_line(Vector2(-16.0, 0), Vector2(0, 0), Color(1.0, 0.5, 0.1), 4.0)
			draw_line(Vector2(-12.0, 0), Vector2(2.0, 0), Color(1.0, 0.95, 0.7), 2.5)
			draw_circle(Vector2(2.0, 0), 2.5, Color.WHITE)
