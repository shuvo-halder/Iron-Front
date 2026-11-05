class_name PooledEffect
extends Node2D

## Lightweight visual explosion/impact effect with auto-recycle into ObjectPool.

var lifetime: float = 0.45
var timer: float = 0.0
var current_scale: float = 1.0

func play_effect(pos: Vector2, p_scale: float = 1.0, is_heavy: bool = false) -> void:
	global_position = pos
	current_scale = p_scale
	scale = Vector2.ONE * p_scale
	timer = lifetime
	queue_redraw()

func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		var pool = get_node_or_null("/root/ObjectPool")
		if pool:
			pool.recycle_explosion(self)
		else:
			queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress: float = 1.0 - (timer / lifetime) # 0 to 1
	var outer_radius: float = (20.0 + progress * 24.0) * current_scale
	var inner_radius: float = maxf(0.0, (14.0 - progress * 14.0)) * current_scale
	
	# Blast shockwave and flame ring
	var alpha: float = clampf(1.0 - progress, 0.0, 1.0)
	draw_circle(Vector2.ZERO, outer_radius, Color(1.0, 0.45, 0.1, alpha * 0.8))
	draw_circle(Vector2.ZERO, inner_radius, Color(1.0, 0.95, 0.4, alpha))
