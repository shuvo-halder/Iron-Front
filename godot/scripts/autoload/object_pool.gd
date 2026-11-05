class_name ObjectPoolAutoload
extends Node

## Object Pooling Manager for Android 60fps Optimization.
## Reuses Projectiles and BattleEffects without runtime allocations or GC spikes.

@export var projectile_scene: PackedScene
@export var explosion_scene: PackedScene

const INITIAL_PROJECTILE_POOL_SIZE: int = 60
const INITIAL_EXPLOSION_POOL_SIZE: int = 40

var _available_projectiles: Array[Node2D] = []
var _active_projectiles: Array[Node2D] = []

var _available_explosions: Array[Node2D] = []
var _active_explosions: Array[Node2D] = []

var _pool_container: Node2D

func _ready() -> void:
	_pool_container = Node2D.new()
	_pool_container.name = "PoolContainer"
	add_child(_pool_container)
	_preload_pools()

func _preload_pools() -> void:
	# Pre-allocate projectiles
	for i in range(INITIAL_PROJECTILE_POOL_SIZE):
		var proj: Node2D = _instantiate_projectile()
		if proj:
			proj.visible = false
			proj.set_process(false)
			_available_projectiles.append(proj)
			_pool_container.add_child(proj)
			
	# Pre-allocate explosions
	for i in range(INITIAL_EXPLOSION_POOL_SIZE):
		var exp_node: Node2D = _instantiate_explosion()
		if exp_node:
			exp_node.visible = false
			exp_node.set_process(false)
			_available_explosions.append(exp_node)
			_pool_container.add_child(exp_node)

func spawn_projectile(start_pos: Vector2, target_pos: Vector2, speed: float, damage: float, armor_pen: float, shooter_faction: int, splash_radius: float = 0.0) -> Node2D:
	var proj: Node2D
	if _available_projectiles.is_empty():
		proj = _instantiate_projectile()
		_pool_container.add_child(proj)
	else:
		proj = _available_projectiles.pop_back()
		
	_active_projectiles.append(proj)
	proj.visible = true
	proj.set_process(true)
	
	if proj.has_method("initialize_projectile"):
		proj.call("initialize_projectile", start_pos, target_pos, speed, damage, armor_pen, shooter_faction, splash_radius)
	return proj

func recycle_projectile(proj: Node2D) -> void:
	var idx := _active_projectiles.find(proj)
	if idx != -1:
		_active_projectiles.remove_at(idx)
	proj.visible = false
	proj.set_process(false)
	_available_projectiles.append(proj)

func spawn_explosion(pos: Vector2, scale_factor: float = 1.0, is_heavy: bool = false) -> Node2D:
	var exp_node: Node2D
	if _available_explosions.is_empty():
		exp_node = _instantiate_explosion()
		_pool_container.add_child(exp_node)
	else:
		exp_node = _available_explosions.pop_back()
		
	_active_explosions.append(exp_node)
	exp_node.visible = true
	exp_node.set_process(true)
	
	if exp_node.has_method("play_effect"):
		exp_node.call("play_effect", pos, scale_factor, is_heavy)
	return exp_node

func recycle_explosion(exp_node: Node2D) -> void:
	var idx := _active_explosions.find(exp_node)
	if idx != -1:
		_active_explosions.remove_at(idx)
	exp_node.visible = false
	exp_node.set_process(false)
	_available_explosions.append(exp_node)

func _instantiate_projectile() -> Node2D:
	if projectile_scene:
		return projectile_scene.instantiate() as Node2D
	var script = load("res://scripts/entities/projectile.gd")
	var node = Area2D.new()
	node.set_script(script)
	return node

func _instantiate_explosion() -> Node2D:
	if explosion_scene:
		return explosion_scene.instantiate() as Node2D
	var script = load("res://scripts/entities/effect_pooled.gd")
	var node = Node2D.new()
	node.set_script(script)
	return node
