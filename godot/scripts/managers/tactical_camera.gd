class_name TacticalCamera
extends Camera2D

## Mobile Tactical Camera with single-finger drag pan, two-finger pinch-to-zoom,
## and full mouse/desktop fallback support. Clamped strictly to map boundaries.

@export var min_zoom: float = 0.5
@export var max_zoom: float = 1.8
@export var zoom_speed: float = 0.08
@export var pan_smoothing: float = 18.0
@export var map_bounds: Rect2 = Rect2(-1280, -768, 2560, 1536)

var target_position: Vector2 = Vector2.ZERO
var target_zoom: float = 1.0

# Desktop mouse drag state
var _is_mouse_panning: bool = false
var _mouse_pan_start: Vector2 = Vector2.ZERO

func _ready() -> void:
	target_position = position
	target_zoom = zoom.x
	_clamp_camera_target()

func _process(delta: float) -> void:
	# Smoothly interpolate position and zoom for fluid touch response
	position = position.lerp(target_position, delta * pan_smoothing)
	var cur_z = lerpf(zoom.x, target_zoom, delta * pan_smoothing)
	zoom = Vector2(cur_z, cur_z)

func pan_by_screen_delta(screen_delta: Vector2) -> void:
	target_position -= screen_delta * (1.0 / zoom.x)
	_clamp_camera_target()

func zoom_at_screen_pos(factor: float, pivot_screen: Vector2 = Vector2.ZERO) -> void:
	var prev_zoom = target_zoom
	target_zoom = clampf(target_zoom * factor, min_zoom, max_zoom)
	
	if not pivot_screen.is_zero_approx():
		var viewport_size = get_viewport_rect().size
		var center_offset = (pivot_screen - viewport_size * 0.5) * (1.0 / prev_zoom - 1.0 / target_zoom)
		target_position += center_offset
	_clamp_camera_target()

func set_map_bounds(bounds: Rect2) -> void:
	map_bounds = bounds
	_clamp_camera_target()

func _clamp_camera_target() -> void:
	var vp_size = get_viewport_rect().size * (1.0 / target_zoom)
	var half_w = vp_size.x * 0.5
	var half_h = vp_size.y * 0.5
	
	var min_x = map_bounds.position.x + half_w
	var max_x = map_bounds.end.x - half_w
	var min_y = map_bounds.position.y + half_h
	var max_y = map_bounds.end.y - half_h
	
	if min_x > max_x:
		target_position.x = map_bounds.get_center().x
	else:
		target_position.x = clampf(target_position.x, min_x, max_x)
		
	if min_y > max_y:
		target_position.y = map_bounds.get_center().y
	else:
		target_position.y = clampf(target_position.y, min_y, max_y)

func _unhandled_input(event: InputEvent) -> void:
	# Desktop Mouse Wheel Zoom Support
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_at_screen_pos(1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_at_screen_pos(0.88, event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_is_mouse_panning = true
				_mouse_pan_start = event.position
			else:
				_is_mouse_panning = false
				
	elif event is InputEventMouseMotion and _is_mouse_panning:
		pan_by_screen_delta(event.relative)
