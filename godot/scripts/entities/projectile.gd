class_name Projectile
extends Area2D

## Pooled ballistic / direct projectile in Iron Front.
## Recycles back to ObjectPool without creating heap garbage.

var speed: float = 450.0
var damage: float = 25.0
var armor_penetration: float = 20.0
var shooter_faction: int = 0
var splash_radius: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var distance_traveled: float = 0.0
var max_range: float = 600.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func initialize_projectile(start_pos: Vector2, target_pos: Vector2, p_speed: float, p_damage: float, p_armor_pen: float, p_faction: int, p_splash: float = 0.0) -> void:
	global_position = start_pos
	speed = p_speed
	damage = p_damage
	armor_penetration = p_armor_pen
	shooter_faction = p_faction
	splash_radius = p_splash
	
	var dir_vec: Vector2 = target_pos - start_pos
	max_range = dir_vec.length() + 30.0
	direction = dir_vec.normalized()
	rotation = direction.angle()
	distance_traveled = 0.0

func _physics_process(delta: float) -> void:
	var move_amt: float = speed * delta
	global_position += direction * move_amt
	distance_traveled += move_amt
	
	if distance_traveled >= max_range:
		_impact(global_position)

func _on_body_entered(body: Node2D) -> void:
	if not visible:
		return
	if body is Unit and body.faction != shooter_faction and not body.is_dead:
		body.take_damage(damage, armor_penetration, direction, null)
		_impact(global_position)

func _impact(pos: Vector2) -> void:
	var pool = get_node_or_null("/root/ObjectPool")
	if pool:
		pool.spawn_explosion(pos, 0.4 if splash_radius == 0.0 else 0.8)
		pool.recycle_projectile(self)
	else:
		queue_free()
