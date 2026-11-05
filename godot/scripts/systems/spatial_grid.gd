class_name SpatialGrid
extends RefCounted

## High performance 2D Spatial Hash Grid for 100+ units on mobile.
## Avoids O(N^2) distance calculations in GDScript.

var cell_size: float = 128.0
var _grid: Dictionary = {} # Vector2i -> Array[CharacterBody2D]

func _init(p_cell_size: float = 128.0) -> void:
	cell_size = p_cell_size

func clear() -> void:
	_grid.clear()

func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / cell_size)), int(floor(pos.y / cell_size)))

func insert(unit: CharacterBody2D) -> void:
	var cell: Vector2i = _world_to_cell(unit.global_position)
	if not _grid.has(cell):
		_grid[cell] = []
	_grid[cell].append(unit)

func query_radius(center: Vector2, radius: float, faction_filter: int = -1) -> Array[CharacterBody2D]:
	var results: Array[CharacterBody2D] = []
	var r2: float = radius * radius
	
	var min_cell: Vector2i = _world_to_cell(center - Vector2(radius, radius))
	var max_cell: Vector2i = _world_to_cell(center + Vector2(radius, radius))
	
	for cx in range(min_cell.x, max_cell.x + 1):
		for cy in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(cx, cy)
			if _grid.has(cell):
				var bucket: Array = _grid[cell]
				for unit in bucket:
					if not is_instance_valid(unit) or unit.is_dead:
						continue
					if faction_filter != -1 and unit.faction != faction_filter:
						continue
					if center.distance_squared_to(unit.global_position) <= r2:
						results.append(unit)
	return results
