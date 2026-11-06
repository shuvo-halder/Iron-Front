class_name BuildManager
extends Node2D

## Handles interactive building placement, grid snapping, and ghost preview.
## Validates terrain, proximity, and supply cost.

@export var building_scene: PackedScene = preload("res://scenes/entities/building.tscn")

var is_building_mode: bool = false
var active_building_data: BuildingData = null
var ghost_position: Vector2 = Vector2.ZERO
var is_placement_valid: bool = false
var grid_snap_size: float = 32.0

var battle_tile_map: BattleTileMap
var main_game: MainGame

func _ready() -> void:
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.building_placement_requested.connect(_on_building_placement_requested)

func setup(p_main_game: MainGame, p_tile_map: BattleTileMap) -> void:
	main_game = p_main_game
	battle_tile_map = p_tile_map

func _on_building_placement_requested(building_res_path: String) -> void:
	var b_data = load(building_res_path) as BuildingData
	if b_data:
		start_placement(b_data)

func start_placement(b_data: BuildingData) -> void:
	active_building_data = b_data
	is_building_mode = true
	visible = true
	queue_redraw()

func cancel_placement() -> void:
	is_building_mode = false
	active_building_data = null
	visible = false
	queue_redraw()

func update_ghost_position(world_pos: Vector2) -> void:
	if not is_building_mode or not active_building_data:
		return

	# Snap to 32px grid
	ghost_position = (world_pos / grid_snap_size).round() * grid_snap_size
	global_position = ghost_position
	is_placement_valid = _check_placement_validity(ghost_position)
	queue_redraw()

func try_place_building() -> bool:
	if not is_building_mode or not active_building_data:
		return false

	if not is_placement_valid:
		return false

	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.spend_supply(active_building_data.supply_cost):
		return false

	# Instantiate building
	var b_node: Building = building_scene.instantiate() as Building
	b_node.global_position = ghost_position
	b_node.data = active_building_data.duplicate() as BuildingData
	b_node.is_under_construction = true

	if main_game and main_game.has_node("Buildings"):
		main_game.get_node("Buildings").add_child(b_node)
	else:
		get_parent().add_child(b_node)

	cancel_placement()
	return true

func _check_placement_validity(pos: Vector2) -> bool:
	if not active_building_data:
		return false

	# 1. Check supply cost
	var gm = get_node_or_null("/root/GameManager")
	if gm and not gm.can_afford(active_building_data.supply_cost):
		return false

	# 2. Check impassable terrain (Water)
	if battle_tile_map and battle_tile_map.is_position_blocked(pos):
		return false

	# 3. Check distance from other buildings
	var r := active_building_data.footprint_radius
	var tree := get_tree()
	if tree:
		var existing_buildings := tree.get_nodes_in_group("buildings")
		for node in existing_buildings:
			if node is Building and is_instance_valid(node):
				var other_r: float = node.data.footprint_radius if node.data else 40.0
				if pos.distance_to(node.global_position) < (r + other_r) * 0.9:
					return false

	return true

func _draw() -> void:
	if not is_building_mode or not active_building_data:
		return

	var r := active_building_data.footprint_radius
	var color := Color(0.2, 0.95, 0.4, 0.55) if is_placement_valid else Color(0.95, 0.2, 0.2, 0.55)
	var border_color := Color(0.2, 1.0, 0.4, 0.9) if is_placement_valid else Color(1.0, 0.2, 0.2, 0.9)

	# Footprint circle + grid snap square
	draw_circle(Vector2.ZERO, r, color)
	draw_arc(Vector2.ZERO, r, 0, TAU, 32, border_color, 2.5)

	# Crosshair alignment guide
	var cross_len := r * 1.3
	draw_line(Vector2(-cross_len, 0), Vector2(cross_len, 0), border_color, 1.5)
	draw_line(Vector2(0, -cross_len), Vector2(0, cross_len), border_color, 1.5)

	# Default rally point preview
	var rally_preview := Vector2(0, r + 45.0)
	draw_line(Vector2.ZERO, rally_preview, Color(1, 1, 1, 0.5), 1.5)
	draw_circle(rally_preview, 4.0, Color.WHITE)
