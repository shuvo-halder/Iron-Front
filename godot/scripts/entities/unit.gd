class_name Unit
extends CharacterBody2D

## Base Unit entity driven by UnitData Resource.
## Features NavigationAgent2D, State Machine (IDLE, MOVE, ATTACK, DEAD),
## HealthBar, SelectionRing, Team Colors, and procedural placeholder shapes.

enum State { IDLE, MOVE, ATTACK, DEAD }

@export var data: UnitData

var current_state: State = State.IDLE
var current_hp: float = 100.0
var is_selected: bool = false
var target_unit: Unit = null
var attack_timer: float = 0.0

# Node references
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D if has_node("NavigationAgent2D") else null
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var selection_ring: Node2D = $SelectionRing if has_node("SelectionRing") else null

# Team Colors: 0 = Allied (Green/Blue), 1 = Axis (Red/Crimson)
const TEAM_COLORS = {
	0: Color(0.25, 0.75, 0.35), # Allied Green
	1: Color(0.85, 0.25, 0.25)  # Axis Red
}

func _ready() -> void:
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
	queue_redraw()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	match current_state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			move_and_slide()

		State.MOVE:
			_process_movement(delta)

		State.ATTACK:
			_process_attack(delta)

func _process_movement(delta: float) -> void:
	if not nav_agent or nav_agent.is_navigation_finished():
		current_state = State.IDLE
		velocity = Vector2.ZERO
		return

	var next_pos := nav_agent.get_next_path_position()
	var dir := (next_pos - global_position).normalized()
	var spd := data.speed if data else 100.0
	var desired_velocity := dir * spd

	rotation = rotate_toward(rotation, dir.angle(), 4.0 * delta)

	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired_velocity)
	else:
		_on_velocity_computed(desired_velocity)

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()

func _process_attack(delta: float) -> void:
	if not is_instance_valid(target_unit) or target_unit.current_state == State.DEAD:
		target_unit = null
		current_state = State.IDLE
		return

	var dist := global_position.distance_to(target_unit.global_position)
	var max_range := data.range if data else 200.0

	if dist > max_range * 1.15:
		# Reposition into range
		set_move_target(target_unit.global_position)
		current_state = State.MOVE
		return

	# Face target
	var dir := (target_unit.global_position - global_position).normalized()
	rotation = rotate_toward(rotation, dir.angle(), 4.5 * delta)

	# Fire weapon when cooldown expires
	if attack_timer <= 0.0:
		attack_timer = data.attack_cooldown if data else 1.0
		_execute_attack(target_unit)

func _execute_attack(target: Unit) -> void:
	var dmg := data.damage if data else 20.0
	var pen := data.armor_penetration if data else 15.0
	target.take_damage(dmg, pen, (target.global_position - global_position).normalized(), self)

	var pool = get_node_or_null("/root/ObjectPool")
	if pool:
		pool.spawn_projectile(global_position, target.global_position, 550.0, dmg, pen, data.team if data else 0)

func take_damage(incoming_damage: float, armor_pen: float, hit_dir: Vector2, _attacker: Unit = null) -> void:
	if current_state == State.DEAD:
		return

	var effective_armor := data.armor_front if data else 10.0
	var local_hit_dir := (-hit_dir).rotated(-rotation)
	if local_hit_dir.dot(Vector2.RIGHT) < -0.5:
		effective_armor = data.armor_rear if data else 4.0

	var diff := effective_armor - armor_pen
	var mult := clampf(1.0 - (diff / (effective_armor + 20.0)), 0.15, 1.5)
	current_hp -= maxf(incoming_damage * mult, 1.0)

	update_visuals()

	if current_hp <= 0.0:
		die()

func die() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	if health_bar:
		health_bar.visible = false
	if selection_ring:
		selection_ring.visible = false

	var pool = get_node_or_null("/root/ObjectPool")
	if pool:
		pool.spawn_explosion(global_position, 1.0)

	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.unit_killed.emit(self, null)

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

func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_ring:
		selection_ring.visible = is_selected
	if health_bar:
		health_bar.visible = is_selected or current_hp < (data.hp if data else 100.0)

func update_visuals() -> void:
	if health_bar and data:
		health_bar.max_value = data.hp
		health_bar.value = current_hp
		health_bar.visible = is_selected or current_hp < data.hp

func _draw() -> void:
	var team_idx := data.team if data else 0
	var color: Color = TEAM_COLORS.get(team_idx, Color.WHITE)
	if current_state == State.DEAD:
		color = Color(0.18, 0.18, 0.18)

	var r := data.unit_radius if data else 18.0
	var u_type := data.unit_type if data else UnitData.UnitType.RIFLE_SQUAD

	# Procedural placeholder shapes per unit type
	match u_type:
		UnitData.UnitType.COMBAT_ENGINEER:
			# Small diamond shape
			var pts := PackedVector2Array([Vector2(r, 0), Vector2(0, -r * 0.7), Vector2(-r, 0), Vector2(0, r * 0.7)])
			draw_colored_polygon(pts, color)
			draw_circle(Vector2.ZERO, r * 0.35, Color(0.9, 0.9, 0.2)) # wrench/tool accent

		UnitData.UnitType.RIFLE_SQUAD:
			# Trio formation
			draw_circle(Vector2(r * 0.4, 0), r * 0.4, color)
			draw_circle(Vector2(-r * 0.35, -r * 0.35), r * 0.35, color)
			draw_circle(Vector2(-r * 0.35, r * 0.35), r * 0.35, color)

		UnitData.UnitType.ANTI_TANK_TEAM:
			# Heavy triangular infantry squad
			var pts := PackedVector2Array([Vector2(r, 0), Vector2(-r * 0.8, -r * 0.7), Vector2(-r * 0.8, r * 0.7)])
			draw_colored_polygon(pts, color)
			draw_line(Vector2(-r * 0.2, 0), Vector2(r * 1.3, 0), Color.BLACK, 3.0) # Rocket tube

		UnitData.UnitType.SCOUT_CAR:
			# Rounded wheeled reconnaissance chassis
			draw_rect(Rect2(-r, -r * 0.6, r * 2.0, r * 1.2), color)
			draw_rect(Rect2(-r * 0.8, -r * 0.8, r * 0.4, r * 0.25), Color.BLACK)
			draw_rect(Rect2(r * 0.4, -r * 0.8, r * 0.4, r * 0.25), Color.BLACK)
			draw_rect(Rect2(-r * 0.8, r * 0.55, r * 0.4, r * 0.25), Color.BLACK)
			draw_rect(Rect2(r * 0.4, r * 0.55, r * 0.4, r * 0.25), Color.BLACK)

		UnitData.UnitType.MEDIUM_TANK:
			# Treads + chassis + turret
			draw_rect(Rect2(-r * 1.1, -r * 0.85, r * 2.2, r * 0.35), Color(0.15, 0.15, 0.15))
			draw_rect(Rect2(-r * 1.1, r * 0.5, r * 2.2, r * 0.35), Color(0.15, 0.15, 0.15))
			draw_rect(Rect2(-r * 0.9, -r * 0.6, r * 1.8, r * 1.2), color)
			draw_circle(Vector2.ZERO, r * 0.55, Color(0.2, 0.2, 0.2))
			draw_line(Vector2.ZERO, Vector2(r * 1.6, 0), Color(0.2, 0.2, 0.2), 4.0)

		UnitData.UnitType.HEAVY_TANK:
			# Massive heavy tracks + long gun barrel
			draw_rect(Rect2(-r * 1.2, -r * 0.95, r * 2.4, r * 0.4), Color(0.1, 0.1, 0.1))
			draw_rect(Rect2(-r * 1.2, r * 0.55, r * 2.4, r * 0.4), Color(0.1, 0.1, 0.1))
			draw_rect(Rect2(-r, -r * 0.7, r * 2.0, r * 1.4), color)
			draw_circle(Vector2.ZERO, r * 0.65, Color(0.15, 0.15, 0.15))
			draw_line(Vector2.ZERO, Vector2(r * 2.1, 0), Color(0.15, 0.15, 0.15), 5.5)
