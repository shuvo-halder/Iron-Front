class_name InputManager
extends Node2D

## Comprehensive Touch and Desktop Input Manager for Iron Front.
## Distinguishes between:
## 1. Single Tap: Quick touch (<0.3s, <16px movement) -> Select / Command
## 2. Long Press: Held stationary (>0.45s) -> Tactical Attack-Move Beacon / Ping
## 3. Drag Box Selection: Dragged >18px -> Multi-Unit Selection Rectangle
## 4. Two-Finger Pinch & Pan: Pinch distance changes zoom; centroid changes camera position.
## Fully compatible with desktop mouse testing (Left-click, Right-click drag, Wheel zoom).

signal tap_detected(world_pos: Vector2, screen_pos: Vector2)
signal long_press_detected(world_pos: Vector2, screen_pos: Vector2)
signal drag_box_updated(start_screen: Vector2, current_screen: Vector2)
signal drag_box_completed(world_rect: Rect2)

@export var camera: TacticalCamera

const TAP_MAX_MOVEMENT: float = 16.0
const DRAG_THRESHOLD: float = 18.0
const LONG_PRESS_DURATION: float = 0.45

# Multi-touch tracking
var _touches: Dictionary = {} # index (int) -> { "start_pos": Vector2, "current_pos": Vector2, "time": float, "is_dragging": bool, "long_pressed": bool }
var _last_pinch_distance: float = 0.0
var _is_box_selecting: bool = false
var _box_start_screen: Vector2 = Vector2.ZERO
var _box_current_screen: Vector2 = Vector2.ZERO

# Desktop mouse tracking
var _mouse_touch_active: bool = false
var _mouse_start_pos: Vector2 = Vector2.ZERO
var _mouse_press_time: float = 0.0
var _mouse_long_pressed: bool = false

func _process(delta: float) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	
	# Check for mobile single-touch long-press
	if _touches.size() == 1:
		for idx in _touches.keys():
			var t = _touches[idx]
			if not t["is_dragging"] and not t["long_pressed"]:
				var held_time: float = current_time - t["time"]
				if held_time >= LONG_PRESS_DURATION:
					t["long_pressed"] = true
					var world_pos := _screen_to_world(t["current_pos"])
					long_press_detected.emit(world_pos, t["current_pos"])
					_trigger_haptic()
					
	# Check for desktop mouse long-press
	if _mouse_touch_active and not _is_box_selecting and not _mouse_long_pressed:
		var held_time: float = current_time - _mouse_press_time
		if held_time >= LONG_PRESS_DURATION:
			_mouse_long_pressed = true
			var world_pos := _screen_to_world(_box_current_screen)
			long_press_detected.emit(world_pos, _box_current_screen)
			_trigger_haptic()

func _unhandled_input(event: InputEvent) -> void:
	# ----------------------------------------------------
	# 1. Native Mobile Touch Events
	# ----------------------------------------------------
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = {
				"start_pos": event.position,
				"current_pos": event.position,
				"time": Time.get_ticks_msec() / 1000.0,
				"is_dragging": false,
				"long_pressed": false
			}
			
			if _touches.size() == 1:
				_box_start_screen = event.position
				_box_current_screen = event.position
			elif _touches.size() == 2:
				# Cancel box select when second finger lands
				_is_box_selecting = false
				_last_pinch_distance = _get_touch_pinch_distance()
				queue_redraw()
		else:
			if _touches.has(event.index):
				var t = _touches[event.index]
				var move_dist: float = t["start_pos"].distance_to(event.position)
				var elapsed: float = (Time.get_ticks_msec() / 1000.0) - t["time"]
				
				if _touches.size() == 1 and not t["long_pressed"]:
					if _is_box_selecting and move_dist >= DRAG_THRESHOLD:
						_finish_box_select(t["start_pos"], event.position)
					elif move_dist < TAP_MAX_MOVEMENT and elapsed < LONG_PRESS_DURATION:
						var world_pos := _screen_to_world(event.position)
						tap_detected.emit(world_pos, event.position)
						
				_touches.erase(event.index)
				if _touches.is_empty():
					_is_box_selecting = false
					_last_pinch_distance = 0.0
					queue_redraw()

	elif event is InputEventScreenDrag:
		if _touches.has(event.index):
			_touches[event.index]["current_pos"] = event.position
			
			# Handle Two-Finger Pinch Zoom and Two-Finger Pan
			if _touches.size() >= 2:
				var current_pinch: float = _get_touch_pinch_distance()
				if _last_pinch_distance > 0.0:
					var pinch_ratio: float = current_pinch / _last_pinch_distance
					if camera:
						camera.zoom_at_screen_pos(pinch_ratio, _get_touch_center_screen())
						camera.pan_by_screen_delta(event.relative * 0.5)
				_last_pinch_distance = current_pinch
				
			# Handle Single-Finger Drag Box Selection or Map Pan
			elif _touches.size() == 1:
				var t = _touches[event.index]
				var dist: float = t["start_pos"].distance_to(event.position)
				if dist >= DRAG_THRESHOLD and not t["long_pressed"]:
					t["is_dragging"] = true
					_is_box_selecting = true
					_box_current_screen = event.position
					drag_box_updated.emit(_box_start_screen, _box_current_screen)
					queue_redraw()

	# ----------------------------------------------------
	# 2. Desktop Mouse Events (Desktop Simulator Testing)
	# ----------------------------------------------------
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_touch_active = true
				_mouse_start_pos = event.position
				_box_start_screen = event.position
				_box_current_screen = event.position
				_mouse_press_time = Time.get_ticks_msec() / 1000.0
				_mouse_long_pressed = false
				_is_box_selecting = false
			else:
				if _mouse_touch_active:
					var dist: float = _mouse_start_pos.distance_to(event.position)
					var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _mouse_press_time
					
					if _is_box_selecting and dist >= DRAG_THRESHOLD:
						_finish_box_select(_mouse_start_pos, event.position)
					elif dist < TAP_MAX_MOVEMENT and elapsed < LONG_PRESS_DURATION and not _mouse_long_pressed:
						var world_pos := _screen_to_world(event.position)
						tap_detected.emit(world_pos, event.position)
						
				_mouse_touch_active = false
				_is_box_selecting = false
				queue_redraw()
				
	elif event is InputEventMouseMotion:
		if _mouse_touch_active:
			_box_current_screen = event.position
			var dist: float = _mouse_start_pos.distance_to(event.position)
			if dist >= DRAG_THRESHOLD and not _mouse_long_pressed:
				_is_box_selecting = true
				drag_box_updated.emit(_box_start_screen, _box_current_screen)
				queue_redraw()

func _finish_box_select(start_screen: Vector2, end_screen: Vector2) -> void:
	var w1 := _screen_to_world(start_screen)
	var w2 := _screen_to_world(end_screen)
	var world_rect := Rect2(
		minf(w1.x, w2.x),
		minf(w1.y, w2.y),
		absf(w2.x - w1.x),
		absf(w2.y - w1.y)
	)
	drag_box_completed.emit(world_rect)
	_is_box_selecting = false
	queue_redraw()

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if camera:
		return camera.get_screen_center_position() + (screen_pos - get_viewport_rect().size * 0.5) * (1.0 / camera.zoom.x)
	return screen_pos

func _get_touch_pinch_distance() -> float:
	var pts = []
	for k in _touches.keys():
		pts.append(_touches[k]["current_pos"])
	if pts.size() >= 2:
		return pts[0].distance_to(pts[1])
	return 0.0

func _get_touch_center_screen() -> Vector2:
	var pts = []
	for k in _touches.keys():
		pts.append(_touches[k]["current_pos"])
	if pts.size() >= 2:
		return (pts[0] + pts[1]) * 0.5
	return get_viewport_rect().size * 0.5

func _trigger_haptic() -> void:
	if Input.has_method("vibrate_handheld"):
		Input.vibrate_handheld(35)

func _draw() -> void:
	if _is_box_selecting:
		var p1 = _box_start_screen
		var p2 = _box_current_screen
		var rect = Rect2(
			minf(p1.x, p2.x),
			minf(p1.y, p2.y),
			absf(p2.x - p1.x),
			absf(p2.y - p1.y)
		)
		# Tactical Green Box with border
		draw_rect(rect, Color(0.2, 0.85, 0.45, 0.2), true)
		draw_rect(rect, Color(0.2, 0.95, 0.5, 0.9), false, 2.0)
