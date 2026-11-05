class_name TacticalCamera
extends Camera2D

## Mobile Tactical Camera with touch panning, pinch-to-zoom, and boundary limits.

@export var pan_speed: float = 1.0
@export var min_zoom: float = 0.5
@export var max_zoom: float = 1.8
@export var map_bounds: Rect2 = Rect2(-1000, -700, 2000, 1400)

var _is_panning: bool = false
var _pan_start_pos: Vector2 = Vector2.ZERO
var _initial_camera_pos: Vector2 = Vector2.ZERO

# Touch gesture state
var _touch_points: Dictionary = {}
var _last_pinch_dist: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
			if _touch_points.is_empty():
				_last_pinch_dist = 0.0
				
	elif event is InputEventScreenDrag:
		_touch_points[event.index] = event.position
		
		# Two finger pinch zoom
		if _touch_points.size() >= 2:
			var pts = _touch_points.values()
			var dist = pts[0].distance_to(pts[1])
			if _last_pinch_dist > 0.0:
				var diff = dist - _last_pinch_dist
				var new_zoom = clampf(zoom.x + diff * 0.003, min_zoom, max_zoom)
				zoom = Vector2(new_zoom, new_zoom)
			_last_pinch_dist = dist
		# Single finger pan when edge dragged or middle-dragged
		elif event.index == 1 or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			position -= event.relative * (1.0 / zoom.x)
			_clamp_position()

func _clamp_position() -> void:
	position.x = clampf(position.x, map_bounds.position.x, map_bounds.end.x)
	position.y = clampf(position.y, map_bounds.position.y, map_bounds.end.y)

func focus_on(world_pos: Vector2) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", world_pos, 0.4)
