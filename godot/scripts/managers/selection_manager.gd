class_name SelectionManager
extends Node2D

## Handles mobile touch input: Single tap select, touch drag box selection,
## move orders, and attack orders.

@export var camera: Camera2D

var selected_units: Array[CharacterBody2D] = []
var is_dragging: bool = false
var drag_start_screen: Vector2 = Vector2.ZERO
var drag_current_screen: Vector2 = Vector2.ZERO
const DRAG_THRESHOLD: float = 18.0

var current_order_mode: int = 0 # 0: Default/Move, 1: Attack-Move, 2: Stop

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start_screen = event.position
				drag_current_screen = event.position
			else:
				if is_dragging:
					var drag_dist = drag_start_screen.distance_to(event.position)
					if drag_dist > DRAG_THRESHOLD:
						_box_select(drag_start_screen, event.position)
					else:
						_handle_tap(event.position)
				is_dragging = false
				queue_redraw()
				
	elif event is InputEventMouseMotion and is_dragging:
		drag_current_screen = event.position
		queue_redraw()

func _handle_tap(screen_pos: Vector2) -> void:
	var world_pos: Vector2 = _screen_to_world(screen_pos)
	
	# Check if user tapped an enemy unit or ally unit
	var clicked_unit = _find_unit_at_world_pos(world_pos)
	
	if clicked_unit != null:
		if clicked_unit.faction == 0: # Allied
			_select_single(clicked_unit)
		else: # Enemy clicked while we have units selected
			if not selected_units.is_empty():
				_issue_attack_order(clicked_unit)
	else:
		# Ground clicked
		if not selected_units.is_empty():
			_issue_ground_order(world_pos)
		else:
			_clear_selection()

func _box_select(screen_start: Vector2, screen_end: Vector2) -> void:
	var world_p1: Vector2 = _screen_to_world(screen_start)
	var world_p2: Vector2 = _screen_to_world(screen_end)
	
	var select_rect = Rect2(
		minf(world_p1.x, world_p2.x),
		minf(world_p1.y, world_p2.y),
		absf(world_p2.x - world_p1.x),
		absf(world_p2.y - world_p1.y)
	)
	
	_clear_selection()
	
	var world = get_parent()
	if world and world.has_method("get_all_allied_units"):
		var allies: Array = world.call("get_all_allied_units")
		for unit in allies:
			if unit is Unit and not unit.is_dead:
				if select_rect.has_point(unit.global_position):
					selected_units.append(unit)
					unit.set_selected(true)
					
	var events = get_node_or_null("/root/GameEvents")
	if events:
		events.emit_units_selection_changed(selected_units)

func _select_single(unit: CharacterBody2D) -> void:
	_clear_selection()
	selected_units.append(unit)
	if unit.has_method("set_selected"):
		unit.call("set_selected", true)
		
	var events = get_node_or_null("/root/GameEvents")
	if events:
		events.emit_unit_selected(unit)
		events.emit_units_selection_changed(selected_units)

func _clear_selection() -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("set_selected"):
			unit.call("set_selected", false)
	selected_units.clear()
	
	var events = get_node_or_null("/root/GameEvents")
	if events:
		events.emit_selection_cleared()

func _issue_ground_order(dest_pos: Vector2) -> void:
	# Calculate spread-out formation so units do not converge onto a single point
	var count = selected_units.size()
	var cols = int(ceil(sqrt(count)))
	var spacing: float = 36.0
	
	for i in range(count):
		var unit = selected_units[i]
		if not is_instance_valid(unit) or (unit is Unit and unit.is_dead):
			continue
			
		var row: int = i / cols
		var col: int = i % cols
		var offset: Vector2 = Vector2((col - cols / 2.0) * spacing, (row - cols / 2.0) * spacing)
		var final_target = dest_pos + offset
		
		if current_order_mode == 1:
			if unit.has_method("order_attack_move"):
				unit.call("order_attack_move", final_target)
		else:
			if unit.has_method("order_move"):
				unit.call("order_move", final_target)

func _issue_attack_order(enemy_unit: CharacterBody2D) -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and not (unit is Unit and unit.is_dead):
			if unit.has_method("order_attack_target"):
				unit.call("order_attack_target", enemy_unit)

func _find_unit_at_world_pos(world_pos: Vector2) -> CharacterBody2D:
	var world = get_parent()
	if world and world.has_method("get_all_units"):
		var all: Array = world.call("get_all_units")
		for u in all:
			if u is Unit and not u.is_dead:
				var radius = u.data.unit_radius if u.data else 20.0
				if world_pos.distance_to(u.global_position) <= radius * 1.4:
					return u
	return null

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if camera:
		return camera.get_screen_center_position() + (screen_pos - get_viewport_rect().size * 0.5) * camera.zoom.x
	return screen_pos

func _draw() -> void:
	if is_dragging:
		var dist = drag_start_screen.distance_to(drag_current_screen)
		if dist > DRAG_THRESHOLD:
			var p1 = drag_start_screen
			var p2 = drag_current_screen
			var rect = Rect2(
				minf(p1.x, p2.x),
				minf(p1.y, p2.y),
				absf(p2.x - p1.x),
				absf(p2.y - p1.y)
			)
			# Semi-transparent tactical green selection box
			draw_rect(rect, Color(0.18, 0.8, 0.44, 0.18), true)
			draw_rect(rect, Color(0.2, 0.95, 0.5, 0.85), false, 2.0)
