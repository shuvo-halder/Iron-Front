class_name ObjectPoolAutoload
extends Node

## Object Pooling Manager for Android 60fps Optimization.
## Reuses Projectiles, Muzzle Flashes, Hit Sparks, Explosions, and Death Wreckage
## without runtime heap allocations or GC pauses.

@export var projectile_scene: PackedScene
@export var explosion_scene: PackedScene

const INITIAL_PROJECTILE_POOL_SIZE: int = 80
const INITIAL_EFFECT_POOL_SIZE: int = 50

var _available_projectiles: Array[Node2D] = []
var _active_projectiles: Array[Node2D] = []

var _available_effects: Array[Node2D] = []
var _active_effects: Array[Node2D] = []

var _pool_container: Node2D

func _ready() -> void:
	_pool_container = Node2D.new()
	_pool_container.name = "PoolContainer"
	add_child(_pool_container)
	_preload_pools()

func _preload_pools() -> void:
	for i in range(INITIAL_PROJECTILE_POOL_SIZE):
		var proj: Node2D = _instantiate_projectile()
		if proj:
			proj.visible = false
			proj.set_process(false)
			proj.set_physics_process(false)
			_available_projectiles.append(proj)
			_pool_container.add_child(proj)

	for i in range(INITIAL_EFFECT_POOL_SIZE):
		var eff: Node2D = _instantiate_effect()
		if eff:
			eff.visible = false
			eff.set_process(false)
			_available_effects.append(eff)
			_pool_container.add_child(eff)

# ----------------- Projectile Pool -----------------
func spawn_projectile(
	start_pos: Vector2,
	target_pos: Vector2,
	speed: float,
	damage: float,
	armor_pen: float,
	shooter_faction: int,
	proj_type: int = 0, # UnitData.ProjectileType.BULLET
	dmg_type: int = 0,  # UnitData.DamageType.KINETIC
	splash_radius: float = 0.0,
	shooter_node: Node2D = null
) -> Node2D:
	var proj: Node2D
	if _available_projectiles.is_empty():
		proj = _instantiate_projectile()
		_pool_container.add_child(proj)
	else:
		proj = _available_projectiles.pop_back()

	_active_projectiles.append(proj)
	proj.visible = true
	proj.set_process(true)
	proj.set_physics_process(true)

	if proj.has_method("initialize_projectile_typed"):
		proj.call("initialize_projectile_typed", start_pos, target_pos, speed, damage, armor_pen, shooter_faction, proj_type, dmg_type, splash_radius, shooter_node)
	elif proj.has_method("initialize_projectile"):
		proj.call("initialize_projectile", start_pos, target_pos, speed, damage, armor_pen, shooter_faction, splash_radius)
	return proj

func recycle_projectile(proj: Node2D) -> void:
	var idx := _active_projectiles.find(proj)
	if idx != -1:
		_active_projectiles.remove_at(idx)
	proj.visible = false
	proj.set_process(false)
	proj.set_physics_process(false)
	_available_projectiles.append(proj)

# ----------------- Visual Effect Pool -----------------
func _get_or_create_effect() -> Node2D:
	var eff: Node2D
	if _available_effects.is_empty():
		eff = _instantiate_effect()
		_pool_container.add_child(eff)
	else:
		eff = _available_effects.pop_back()
	_active_effects.append(eff)
	eff.visible = true
	eff.set_process(true)
	return eff

func spawn_muzzle_flash(pos: Vector2, dir: Vector2, scale_factor: float = 1.0) -> Node2D:
	var eff := _get_or_create_effect()
	if eff.has_method("play_muzzle_flash"):
		eff.call("play_muzzle_flash", pos, dir, scale_factor)
	return eff

func spawn_hit_effect(pos: Vector2, hit_normal: Vector2, is_armor: bool = true, scale_factor: float = 1.0) -> Node2D:
	var eff := _get_or_create_effect()
	if eff.has_method("play_hit_spark"):
		eff.call("play_hit_spark", pos, hit_normal, is_armor, scale_factor)
	return eff

func spawn_explosion(pos: Vector2, scale_factor: float = 1.0, is_heavy: bool = false) -> Node2D:
	var eff := _get_or_create_effect()
	if eff.has_method("play_explosion"):
		eff.call("play_explosion", pos, scale_factor, is_heavy)
	elif eff.has_method("play_effect"):
		eff.call("play_effect", pos, scale_factor, is_heavy)
	return eff

func spawn_death_effect(pos: Vector2, is_vehicle: bool = false, scale_factor: float = 1.0) -> Node2D:
	var eff := _get_or_create_effect()
	if eff.has_method("play_death_wreckage"):
		eff.call("play_death_wreckage", pos, is_vehicle, scale_factor)
	elif eff.has_method("play_explosion"):
		eff.call("play_explosion", pos, scale_factor * 1.5, true)
	return eff

func recycle_explosion(eff_node: Node2D) -> void:
	var idx := _active_effects.find(eff_node)
	if idx != -1:
		_active_effects.remove_at(idx)
	eff_node.visible = false
	eff_node.set_process(false)
	_available_effects.append(eff_node)

func _instantiate_projectile() -> Node2D:
	if projectile_scene:
		return projectile_scene.instantiate() as Node2D
	var script = load("res://scripts/entities/projectile.gd")
	var node = Area2D.new()
	node.set_script(script)
	return node

func _instantiate_effect() -> Node2D:
	if explosion_scene:
		return explosion_scene.instantiate() as Node2D
	var script = load("res://scripts/entities/effect_pooled.gd")
	var node = Node2D.new()
	node.set_script(script)
	return node
