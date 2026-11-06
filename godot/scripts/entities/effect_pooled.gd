class_name PooledEffect
extends Node2D

## Lightweight zero-allocation visual particle/effect renderer.
## Supports Muzzle Flash, Hit Sparks, Explosions, and Death Wreckage with auto-recycling.

enum EffectType {
	MUZZLE_FLASH,
	HIT_SPARK,
	EXPLOSION,
	DEATH_WRECKAGE
}

var effect_type: EffectType = EffectType.EXPLOSION
var lifetime: float = 0.4
var timer: float = 0.0
var current_scale: float = 1.0
var effect_color: Color = Color(1.0, 0.7, 0.2)
var debris_points: PackedVector2Array = []
var debris_velocities: PackedVector2Array = []

func play_muzzle_flash(pos: Vector2, dir: Vector2, scale_factor: float = 1.0) -> void:
	global_position = pos
	rotation = dir.angle()
	effect_type = EffectType.MUZZLE_FLASH
	current_scale = scale_factor
	lifetime = 0.08
	timer = lifetime
	scale = Vector2.ONE * scale_factor
	queue_redraw()

func play_hit_spark(pos: Vector2, hit_normal: Vector2, is_armor: bool = true, scale_factor: float = 1.0) -> void:
	global_position = pos
	rotation = hit_normal.angle()
	effect_type = EffectType.HIT_SPARK
	current_scale = scale_factor
	lifetime = 0.18
	timer = lifetime
	effect_color = Color(1.0, 0.85, 0.3) if is_armor else Color(0.8, 0.3, 0.2)
	
	debris_points.clear()
	debris_velocities.clear()
	for i in range(5):
		debris_points.append(Vector2.ZERO)
		var spread_angle := randf_range(-0.8, 0.8)
		var spd := randf_range(60.0, 160.0)
		debris_velocities.append(Vector2.RIGHT.rotated(spread_angle) * spd)
		
	queue_redraw()

func play_explosion(pos: Vector2, scale_factor: float = 1.0, is_heavy: bool = false) -> void:
	global_position = pos
	rotation = randf() * TAU
	effect_type = EffectType.EXPLOSION
	current_scale = scale_factor
	lifetime = 0.42 if is_heavy else 0.32
	timer = lifetime
	scale = Vector2.ONE * scale_factor
	queue_redraw()

func play_death_wreckage(pos: Vector2, is_vehicle: bool = false, scale_factor: float = 1.0) -> void:
	global_position = pos
	rotation = randf() * TAU
	effect_type = EffectType.DEATH_WRECKAGE
	current_scale = scale_factor
	lifetime = 0.85
	timer = lifetime
	
	debris_points.clear()
	debris_velocities.clear()
	var debris_count := 8 if is_vehicle else 5
	for i in range(debris_count):
		debris_points.append(Vector2.ZERO)
		var ang := randf() * TAU
		var spd := randf_range(80.0, 220.0) * scale_factor
		debris_velocities.append(Vector2(cos(ang), sin(ang)) * spd)
		
	queue_redraw()

# Backwards compatibility
func play_effect(pos: Vector2, p_scale: float = 1.0, is_heavy: bool = false) -> void:
	play_explosion(pos, p_scale, is_heavy)

func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		var pool = get_node_or_null("/root/ObjectPool")
		if pool:
			pool.recycle_explosion(self)
		else:
			queue_free()
		return

	# Update debris particle physics
	if effect_type == EffectType.HIT_SPARK or effect_type == EffectType.DEATH_WRECKAGE:
		for i in range(debris_points.size()):
			debris_points[i] += debris_velocities[i] * delta
			debris_velocities[i] *= 0.92

	queue_redraw()

func _draw() -> void:
	var progress := 1.0 - (timer / lifetime) # 0 to 1
	var alpha := clampf(1.0 - progress, 0.0, 1.0)

	match effect_type:
		EffectType.MUZZLE_FLASH:
			# Bright explosive cone + star flash at barrel tip
			var flash_len := 22.0 * current_scale
			var flash_width := 14.0 * current_scale
			var cone := PackedVector2Array([
				Vector2.ZERO,
				Vector2(flash_len, -flash_width * 0.5),
				Vector2(flash_len * 1.25, 0),
				Vector2(flash_len, flash_width * 0.5)
			])
			draw_colored_polygon(cone, Color(1.0, 0.95, 0.6, alpha))
			draw_circle(Vector2.ZERO, 6.0 * current_scale, Color(1.0, 1.0, 1.0, alpha))

		EffectType.HIT_SPARK:
			# Fast radiating kinetic sparks
			for i in range(debris_points.size()):
				var pt := debris_points[i]
				var spark_color := Color(effect_color.r, effect_color.g, effect_color.b, alpha)
				draw_line(pt, pt - debris_velocities[i] * 0.04, spark_color, 2.0)
				draw_circle(pt, 2.0, Color.WHITE)

		EffectType.EXPLOSION:
			# Expanding shockwave + fiery core + inner flash
			var shock_radius := (16.0 + progress * 32.0) * current_scale
			var fire_radius := maxf(0.0, (18.0 - progress * 14.0) * current_scale)
			var flash_radius := maxf(0.0, (10.0 - progress * 10.0)) * current_scale

			# Outer smoke/shockwave
			draw_arc(Vector2.ZERO, shock_radius, 0, TAU, 24, Color(0.9, 0.45, 0.1, alpha * 0.7), 3.0 * current_scale)
			# Mid orange blast
			draw_circle(Vector2.ZERO, fire_radius, Color(1.0, 0.4, 0.08, alpha * 0.85))
			# Hot core flash
			draw_circle(Vector2.ZERO, flash_radius, Color(1.0, 0.95, 0.4, alpha))

		EffectType.DEATH_WRECKAGE:
			# Scorched crater on ground + expanding debris ring + black smoke puffs
			var scorch_r := 28.0 * current_scale
			var scorch_alpha := clampf(0.55 * (1.0 - progress * 0.5), 0.0, 0.55)
			draw_circle(Vector2.ZERO, scorch_r, Color(0.12, 0.12, 0.12, scorch_alpha))

			var ring_r := (20.0 + progress * 40.0) * current_scale
			draw_arc(Vector2.ZERO, ring_r, 0, TAU, 28, Color(1.0, 0.5, 0.1, alpha * 0.8), 4.0)

			# Flying flaming debris
			for i in range(debris_points.size()):
				var pt := debris_points[i]
				draw_circle(pt, 3.5 * current_scale, Color(0.2, 0.2, 0.2, alpha))
				draw_circle(pt, 2.0 * current_scale, Color(1.0, 0.6, 0.1, alpha))
