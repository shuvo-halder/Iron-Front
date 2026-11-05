class_name Unit
extends CharacterBody2D

## Iron Front Tactical Unit base class.
## Handles state machine, steering separation, combat armor calculations,
## turret tracking, and signal integration.

enum State {
	IDLE,
	MOVE,
	ATTACK_MOVE,
	ATTACK_TARGET,
	DESTROYED
}

@export var data: UnitData

var state: State = State.IDLE
var faction: int = 0
var current_health: float = 100.0
var is_dead: bool = false
var is_selected: bool = false

# Movement
var target_destination: Vector2 = Vector2.ZERO
var stop_distance: float = 24.0

# Combat
var current_target: Unit = null
var reload_timer: float = 0.0
var target_scan_timer: float = 0.0
var target_scan_interval: float = 0.2 # Staggered AI interval for 60fps mobile

# Node references
@onready var hull_sprite: Node2D = $Hull
@onready var turret_node: Node2D = $Turret
@onready var muzzle_node: Marker2D = $Turret/Muzzle if has_node("Turret/Muzzle") else null
@onready var selection_ring: Node2D = $SelectionRing
@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	if data:
		initialize_from_data(data)
	else:
		# Fallback defaults
		current_health = 100.0
		
	# Randomize scan timer so 100 units don't scan simultaneously
	target_scan_timer = randf_range(0.0, target_scan_interval)
	update_visuals()

func initialize_from_data(p_data: UnitData) -> void:
	data = p_data
	faction = data.faction
	current_health = data.max_health
	stop_distance = data.unit_radius * 1.5

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# Tick reload timer
	if reload_timer > 0.0:
		reload_timer -= delta
		
	# Staggered AI enemy scan
	target_scan_timer -= delta
	if target_scan_timer <= 0.0:
		target_scan_timer = target_scan_interval + randf_range(-0.03, 0.03)
		_evaluate_targeting()
		
	# State machine execution
	match state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, data.acceleration * delta if data else 400.0 * delta)
			move_and_slide()
			_track_turret(delta)
			
		State.MOVE:
			_process_movement(delta)
			_track_turret(delta)
			
		State.ATTACK_MOVE:
			if is_instance_valid(current_target) and not current_target.is_dead:
				var dist: float = global_position.distance_to(current_target.global_position)
				if dist <= data.attack_range:
					state = State.ATTACK_TARGET
				else:
					target_destination = current_target.global_position
					_process_movement(delta)
			else:
				_process_movement(delta)
			_track_turret(delta)
			
		State.ATTACK_TARGET:
			if not is_instance_valid(current_target) or current_target.is_dead:
				current_target = null
				state = State.IDLE
			else:
				var dist: float = global_position.distance_to(current_target.global_position)
				if dist > data.attack_range * 1.15:
					# Target fled out of range, pursue
					target_destination = current_target.global_position
					_process_movement(delta)
				else:
					# In range, hold ground and engage
					velocity = velocity.move_toward(Vector2.ZERO, data.acceleration * delta if data else 400.0 * delta)
					move_and_slide()
					_attempt_fire_weapon()
			_track_turret(delta)

func _process_movement(delta: float) -> void:
	var to_dest: Vector2 = target_destination - global_position
	var dist: float = to_dest.length()
	
	if dist <= stop_distance:
		velocity = Vector2.ZERO
		state = State.IDLE
		move_and_slide()
		return
		
	var desired_dir: Vector2 = to_dest.normalized()
	
	# Hull rotation
	var target_angle: float = desired_dir.angle()
	rotation = rotate_toward(rotation, target_angle, (data.rotation_speed if data else 3.5) * delta)
	
	# Separation / Flocking force to prevent clumping
	var separation: Vector2 = _calculate_separation_force()
	var final_dir: Vector2 = (desired_dir + separation * 0.65).normalized()
	
	velocity = final_dir * (data.move_speed if data else 120.0)
	move_and_slide()

func _calculate_separation_force() -> Vector2:
	# Light separation against nearby units using collision or neighbor array
	var force: Vector2 = Vector2.ZERO
	var count: int = 0
	var radius: float = data.unit_radius * 2.2 if data else 45.0
	
	for i in range(get_slide_collision_count()):
		var col: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = col.get_collider()
		if collider is Unit and collider != self:
			var diff: Vector2 = global_position - collider.global_position
			var d: float = diff.length()
			if d > 0.001 and d < radius:
				force += (diff / d) * (1.0 - d / radius)
				count += 1
	return force if count == 0 else force / float(count)

func _evaluate_targeting() -> void:
	if not data:
		return
	if is_instance_valid(current_target) and not current_target.is_dead:
		return # Keep tracking current target
		
	# Find closest enemy using GameEvents / World query
	var parent_world = get_parent()
	if parent_world and parent_world.has_method("find_nearest_enemy"):
		current_target = parent_world.call("find_nearest_enemy", global_position, data.vision_range, faction)

func _track_turret(delta: float) -> void:
	if not turret_node:
		return
	var target_rot: float = 0.0
	if is_instance_valid(current_target) and not current_target.is_dead:
		var dir_to_target: Vector2 = current_target.global_position - global_position
		target_rot = dir_to_target.angle() - rotation
	else:
		target_rot = 0.0 # Align with hull
		
	var rot_speed: float = (data.turret_rotation_speed if data else 4.0) * delta
	turret_node.rotation = rotate_toward(turret_node.rotation, target_rot, rot_speed)

func _attempt_fire_weapon() -> void:
	if reload_timer > 0.0 or not is_instance_valid(current_target) or current_target.is_dead:
		return
		
	# Check aim angle tolerance
	var turret_global_angle: float = rotation + turret_node.rotation if turret_node else rotation
	var dir_to_target: Vector2 = (current_target.global_position - global_position).normalized()
	var angle_diff: float = abs(wrapf(dir_to_target.angle() - turret_global_angle, -PI, PI))
	
	if angle_diff > deg_to_rad(20.0):
		return # Turret still aligning
		
	reload_timer = data.reload_time if data else 1.2
	var fire_pos: Vector2 = muzzle_node.global_position if muzzle_node else global_position
	
	# Use ObjectPool autoload for zero garbage generation
	var pool = get_node_or_null("/root/ObjectPool")
	if pool:
		pool.spawn_projectile(
			fire_pos,
			current_target.global_position,
			data.projectile_speed if data else 450.0,
			data.damage if data else 25.0,
			data.armor_penetration if data else 20.0,
			faction,
			data.splash_radius if data else 0.0
		)

func take_damage(incoming_damage: float, armor_penetration: float, hit_direction: Vector2, attacker: Unit = null) -> void:
	if is_dead:
		return
		
	# Determine hit angle relative to hull: Front, Side, or Rear
	var local_hit_dir: Vector2 = (-hit_direction).rotated(-rotation)
	var forward: Vector2 = Vector2.RIGHT
	var dot: float = local_hit_dir.dot(forward)
	
	var effective_armor: float = data.armor_front if data else 20.0
	if dot < -0.5:
		effective_armor = data.armor_rear if data else 5.0 # Critical rear hit!
	elif abs(dot) <= 0.5:
		effective_armor = data.armor_side if data else 10.0 # Flank hit
		
	# Damage mitigation formula: armor absorbs penetration
	var armor_diff: float = effective_armor - armor_penetration
	var damage_multiplier: float = 1.0
	if armor_diff > 0:
		damage_multiplier = clampf(1.0 - (armor_diff / (effective_armor + 20.0)), 0.15, 1.0)
	else:
		damage_multiplier = 1.0 + clampf(abs(armor_diff) / 50.0, 0.0, 0.5)
		
	var final_damage: float = maxf(incoming_damage * damage_multiplier, 1.0)
	current_health -= final_damage
	
	update_visuals()
	
	# Retaliate if idle
	if state == State.IDLE and attacker != null and not is_instance_valid(current_target):
		current_target = attacker
		state = State.ATTACK_TARGET
		
	if current_health <= 0.0:
		die(attacker)

func die(killer: Unit = null) -> void:
	if is_dead:
		return
	is_dead = true
	state = State.DESTROYED
	
	# Spawn explosion via ObjectPool
	var pool = get_node_or_null("/root/ObjectPool")
	if pool:
		pool.spawn_explosion(global_position, 1.2 if (data and data.unit_type != UnitData.UnitType.INFANTRY) else 0.6)
		
	var events = get_node_or_null("/root/GameEvents")
	if events:
		events.emit_unit_killed(self, killer)
		
	queue_free()

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_ring:
		selection_ring.visible = is_selected

func order_move(dest: Vector2) -> void:
	target_destination = dest
	current_target = null
	state = State.MOVE

func order_attack_move(dest: Vector2) -> void:
	target_destination = dest
	state = State.ATTACK_MOVE

func order_attack_target(target: Unit) -> void:
	current_target = target
	state = State.ATTACK_TARGET

func order_stop() -> void:
	current_target = null
	state = State.IDLE
	velocity = Vector2.ZERO

func update_visuals() -> void:
	if health_bar and data:
		health_bar.max_value = data.max_health
		health_bar.value = current_health
		health_bar.visible = current_health < data.max_health or is_selected
