class_name OrderMarker
extends Node2D

## Visual tactical order marker (Move or Attack waypoint).
## Green pulsing ring for move orders; Red tactical crosshairs for attack orders.

enum MarkerType { MOVE, ATTACK }

var marker_type: MarkerType = MarkerType.MOVE
var lifetime: float = 0.55
var timer: float = 0.0

func setup_marker(pos: Vector2, p_type: MarkerType = MarkerType.MOVE) -> void:
	global_position = pos
	marker_type = p_type
	timer = lifetime
	queue_redraw()

func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress := 1.0 - (timer / lifetime) # 0 to 1
	var alpha := clampf(1.0 - progress, 0.0, 1.0)

	if marker_type == MarkerType.MOVE:
		# Green pulsing waypoint circle + inner diamond
		var radius := 12.0 + progress * 24.0
		var color := Color(0.2, 0.95, 0.45, alpha)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 24, color, 2.5)

		var inner_size := maxf(0.0, 6.0 - progress * 4.0)
		var pts := PackedVector2Array([
			Vector2(0, -inner_size),
			Vector2(inner_size, 0),
			Vector2(0, inner_size),
			Vector2(-inner_size, 0)
		])
		draw_colored_polygon(pts, color)
	else:
		# Red targeting crosshairs
		var radius := 28.0 - progress * 10.0
		var color := Color(0.95, 0.25, 0.25, alpha)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 24, color, 2.5)
		# 4 crosshair tick marks
		var tick_len := 8.0
		draw_line(Vector2(0, -radius - tick_len), Vector2(0, -radius + tick_len), color, 2.0)
		draw_line(Vector2(0, radius - tick_len), Vector2(0, radius + tick_len), color, 2.0)
		draw_line(Vector2(-radius - tick_len, 0), Vector2(-radius + tick_len, 0), color, 2.0)
		draw_line(Vector2(radius - tick_len, 0), Vector2(radius + tick_len, 0), color, 2.0)
