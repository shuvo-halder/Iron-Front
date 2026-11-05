class_name BattleTileMap
extends TileMap

## Battle TileMap managing terrain types and traversal modifiers.
## Terrain Types:
## 0: GRASS (Normal speed 1.0x)
## 1: ROAD (Speed boost 1.3x)
## 2: WATER (Blocked / impassable)
## 3: FOREST (Slowed 0.6x, provides 25% cover defense)

enum TerrainType {
	GRASS = 0,
	ROAD = 1,
	WATER = 2,
	FOREST = 3
}

@export var map_size_tiles: Vector2i = Vector2i(40, 24)
@export var tile_dimension: int = 64

# Terrain definitions: [Name, SpeedMult, IsBlocked, DefenseBonus, Color]
const TERRAIN_CONFIG = {
	TerrainType.GRASS: { "name": "Grass", "speed": 1.0, "blocked": false, "defense": 0.0, "color": Color(0.24, 0.35, 0.22) },
	TerrainType.ROAD: { "name": "Road", "speed": 1.35, "blocked": false, "defense": 0.0, "color": Color(0.42, 0.40, 0.36) },
	TerrainType.WATER: { "name": "Water", "speed": 0.0, "blocked": true, "defense": 0.0, "color": Color(0.18, 0.32, 0.45) },
	TerrainType.FOREST: { "name": "Forest", "speed": 0.6, "blocked": false, "defense": 0.25, "color": Color(0.15, 0.25, 0.14) }
}

var _terrain_grid: Dictionary = {} # Vector2i -> TerrainType

func _ready() -> void:
	_generate_procedural_tactical_map()

func get_map_world_bounds() -> Rect2:
	var total_w = map_size_tiles.x * tile_dimension
	var total_h = map_size_tiles.y * tile_dimension
	return Rect2(-total_w * 0.5, -total_h * 0.5, total_w, total_h)

func _generate_procedural_tactical_map() -> void:
	# Build in-memory terrain grid
	for x in range(-map_size_tiles.x / 2, map_size_tiles.x / 2):
		for y in range(-map_size_tiles.y / 2, map_size_tiles.y / 2):
			var cell = Vector2i(x, y)
			
			# Horizontal main road through the center
			if y == 0 or y == 1:
				_terrain_grid[cell] = TerrainType.ROAD
			# Meandering river across the map (x = 2 to 4) with a bridge on the road
			elif (x >= 2 and x <= 4) and not (y >= -1 and y <= 2):
				_terrain_grid[cell] = TerrainType.WATER
			# Forest clusters for ambush cover
			elif (x < -10 and abs(y) > 4) or (x > 10 and abs(y) > 5) or (x == -4 and y == -6):
				_terrain_grid[cell] = TerrainType.FOREST
			else:
				_terrain_grid[cell] = TerrainType.GRASS
				
	queue_redraw()

func _draw() -> void:
	# Procedural canvas rendering for instant 60 FPS mobile performance without asset dependencies
	for cell in _terrain_grid.keys():
		var t_type: int = _terrain_grid[cell]
		var cfg = TERRAIN_CONFIG[t_type]
		var world_pos = Vector2(cell.x * tile_dimension, cell.y * tile_dimension)
		var rect = Rect2(world_pos, Vector2(tile_dimension, tile_dimension))
		
		draw_rect(rect, cfg["color"])
		# Grid contour border
		draw_rect(rect, Color(0, 0, 0, 0.08), false, 1.0)
		
		# Forest canopy or water wave accent lines
		if t_type == TerrainType.FOREST:
			draw_circle(world_pos + Vector2(tile_dimension * 0.5, tile_dimension * 0.5), tile_dimension * 0.35, Color(0.12, 0.20, 0.11))
		elif t_type == TerrainType.ROAD:
			draw_line(world_pos + Vector2(0, tile_dimension * 0.5), world_pos + Vector2(tile_dimension, tile_dimension * 0.5), Color(0.55, 0.52, 0.45, 0.4), 2.0)
		elif t_type == TerrainType.WATER:
			draw_line(world_pos + Vector2(8, 20), world_pos + Vector2(tile_dimension - 8, 20), Color(0.28, 0.48, 0.65, 0.5), 1.5)

func get_terrain_at_world_pos(world_pos: Vector2) -> int:
	var cell = Vector2i(int(floor(world_pos.x / tile_dimension)), int(floor(world_pos.y / tile_dimension)))
	return _terrain_grid.get(cell, TerrainType.GRASS)

func get_speed_multiplier(world_pos: Vector2) -> float:
	var t_type = get_terrain_at_world_pos(world_pos)
	return TERRAIN_CONFIG[t_type]["speed"]

func is_position_blocked(world_pos: Vector2) -> bool:
	var t_type = get_terrain_at_world_pos(world_pos)
	return TERRAIN_CONFIG[t_type]["blocked"]

func get_cover_defense_bonus(world_pos: Vector2) -> float:
	var t_type = get_terrain_at_world_pos(world_pos)
	return TERRAIN_CONFIG[t_type]["defense"]
